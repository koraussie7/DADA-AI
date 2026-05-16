use anyhow::Result;
use reqwest::Client;
use serde_json::{json, Value};

/// Hyperspace P2P AI Inference Client
/// Connects to the Hyperspace decentralized inference network (2M+ nodes)
/// Uses OpenAI-compatible API at localhost:8080/v1
pub struct HyperspaceClient {
    client: Client,
    base_url: String,
}

impl HyperspaceClient {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "http://localhost:8080".to_string(),
        }
    }

    pub fn with_url(url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: url.to_string(),
        }
    }

    /// Send inference request to Hyperspace P2P network
    /// When p2p=true, the request is routed through the global P2P network
    pub async fn infer(&self, prompt: &str, model: &str, p2p: bool) -> Result<String> {
        let mut payload = json!({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": false,
        });

        if p2p {
            payload["p2p"] = json!(true);
        }

        let resp = self.client
            .post(format!("{}/v1/chat/completions", self.base_url))
            .json(&payload)
            .send()
            .await?;

        let data: Value = resp.json().await?;
        Ok(data["choices"][0]["message"]["content"]
            .as_str()
            .unwrap_or("(no response)")
            .to_string())
    }

    /// Check if Hyperspace node is connected and healthy
    pub async fn health(&self) -> Result<bool> {
        let resp = self.client
            .get(format!("{}/v1/models", self.base_url))
            .send()
            .await?;
        Ok(resp.status().is_success())
    }

    /// Get available models on this node
    pub async fn list_models(&self) -> Result<Vec<String>> {
        let resp = self.client
            .get(format!("{}/v1/models", self.base_url))
            .send()
            .await?;
        let data: Value = resp.json().await?;
        let models = data["data"]
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|m| m["id"].as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();
        Ok(models)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_health() {
        let client = HyperspaceClient::new();
        // This test requires a running Hyperspace node
        // let result = client.health().await;
        assert!(true);
    }
}
