use reqwest::Client;
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
struct OpenCodeRequest {
    model: String,
    messages: Vec<Message>,
    temperature: f32,
    max_tokens: u32,
}

#[derive(Serialize, Deserialize)]
struct Message {
    role: String,
    content: String,
}

#[derive(Deserialize)]
struct OpenCodeResponse {
    choices: Vec<Choice>,
}

#[derive(Deserialize)]
struct Choice {
    message: Message,
}

#[derive(Clone)]
pub struct OpenCodeClient {
    client: Client,
    base_url: String,
    api_key: String,
}

impl OpenCodeClient {
    pub fn new(base_url: String, api_key: String) -> Self {
        Self { client: Client::new(), base_url, api_key }
    }

    pub async fn chat(
        &self,
        prompt: &str,
        system_prompt: Option<&str>,
        model: Option<&str>,
    ) -> anyhow::Result<String> {
        let mut messages = Vec::new();

        if let Some(sp) = system_prompt {
            messages.push(Message {
                role: "system".to_string(),
                content: sp.to_string(),
            });
        }

        messages.push(Message {
            role: "user".to_string(),
            content: prompt.to_string(),
        });

        let payload = OpenCodeRequest {
            model: model.unwrap_or("claude-sonnet-4").to_string(),
            messages,
            temperature: 0.7,
            max_tokens: 4096,
        };

        let resp = self
            .client
            .post(format!("{}/v1/chat/completions", self.base_url))
            .header("Authorization", format!("Bearer {}", self.api_key))
            .json(&payload)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            anyhow::bail!("OpenCode error ({}): {}", status, body);
        }

        let data: OpenCodeResponse = resp.json().await?;
        Ok(data.choices.into_iter().next().map(|c| c.message.content).unwrap_or_default())
    }

    pub async fn health(&self) -> bool {
        self.client.get(format!("{}/health", self.base_url))
            .send()
            .await
            .map(|r| r.status().is_success())
            .unwrap_or(false)
    }
}
