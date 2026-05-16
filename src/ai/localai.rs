use reqwest::Client;
use serde_json::json;

#[derive(Clone)]
pub struct LocalAIClient {
    client: Client,
    base_url: String,
    model: String,
}

impl LocalAIClient {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "http://localhost:8081".to_string(),
            model: "gemma3:4b".to_string(),
        }
    }

    pub async fn generate(&self, prompt: &str) -> anyhow::Result<String> {
        let payload = json!({
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": false,
            "max_tokens": 2048,
            "temperature": 0.7,
        });

        let resp = self
            .client
            .post(format!("{}/v1/chat/completions", self.base_url))
            .json(&payload)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            anyhow::bail!("LocalAI error ({}): {}", status, body);
        }

        let data: serde_json::Value = resp.json().await?;
        let msg = &data["choices"][0]["message"];
        Ok(msg["content"]
            .as_str()
            .filter(|s| !s.is_empty())
            .or_else(|| msg["reasoning"].as_str())
            .unwrap_or("(no response)")
            .to_string())
    }

    pub async fn health(&self) -> bool {
        match self
            .client
            .get(format!("{}/v1/models", self.base_url))
            .send()
            .await
        {
            Ok(resp) => resp.status().is_success(),
            Err(_) => false,
        }
    }
}
