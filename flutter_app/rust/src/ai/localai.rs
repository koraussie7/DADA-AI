use reqwest::Client;
use serde_json::json;

#[derive(Clone)]
pub struct LocalAIClient {
    client: Client,
    base_url: String,
}

impl LocalAIClient {
    pub fn new(base_url: String) -> Self {
        Self {
            client: Client::new(),
            base_url,
        }
    }

    pub async fn generate(&self, prompt: &str) -> anyhow::Result<String> {
        let payload = json!({
            "model": "gemma-2-2b-it",
            "prompt": prompt,
            "stream": false,
            "max_tokens": 1024,
            "temperature": 0.7,
        });

        let resp = self
            .client
            .post(format!("{}/v1/completions", self.base_url))
            .json(&payload)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let text = resp.text().await.unwrap_or_default();
            anyhow::bail!("LocalAI error ({}): {}", status, text);
        }

        let data: serde_json::Value = resp.json().await?;
        Ok(data["choices"][0]["text"]
            .as_str()
            .unwrap_or("(no response)")
            .to_string())
    }

    pub async fn health(&self) -> bool {
        match self
            .client
            .get(format!("{}/healthz", self.base_url))
            .send()
            .await
        {
            Ok(resp) => resp.status().is_success(),
            Err(_) => false,
        }
    }
}
