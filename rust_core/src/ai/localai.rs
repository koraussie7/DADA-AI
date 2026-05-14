use reqwest::Client;
use serde_json::json;

#[derive(Clone)]
pub struct LocalAIClient {
    client: Client,
    base_url: String,
}

impl LocalAIClient {
    pub fn new(base_url: String) -> Self {
        Self { client: Client::new(), base_url }
    }

    /// Text-only chat (gemma3:4b)
    pub async fn generate(&self, prompt: &str) -> anyhow::Result<String> {
        let payload = json!({
            "model": "gemma3:4b",
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
            anyhow::bail!("LocalAI error: {}", resp.status());
        }

        let data: serde_json::Value = resp.json().await?;
        Ok(data["choices"][0]["message"]["content"]
            .as_str()
            .unwrap_or("(no response)")
            .to_string())
    }

    /// Multimodal (text + images) via gemma3:4b with mmproj
    pub async fn generate_multimodal(
        &self,
        text: &str,
        images: Vec<String>,
    ) -> anyhow::Result<String> {
        let mut content: Vec<serde_json::Value> = vec![
            json!({"type": "text", "text": text})
        ];

        for img in &images {
            content.push(json!({
                "type": "image_url",
                "image_url": { "url": format!("data:image/jpeg;base64,{}", img) }
            }));
        }

        let payload = json!({
            "model": "gemma3:4b",
            "messages": [{"role": "user", "content": content}],
            "max_tokens": 4096,
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
            anyhow::bail!("Gemma-4 multimodal error ({}): {}", status, body);
        }

        let data: serde_json::Value = resp.json().await?;
        Ok(data["choices"][0]["message"]["content"]
            .as_str()
            .unwrap_or("(no response)")
            .to_string())
    }

    pub async fn health(&self) -> bool {
        match self.client.get(format!("{}/healthz", self.base_url)).send().await {
            Ok(resp) => resp.status().is_success(),
            Err(_) => false,
        }
    }
}
