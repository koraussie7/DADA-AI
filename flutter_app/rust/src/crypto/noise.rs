use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct SignedMessage {
    pub sender: String,
    pub content: String,
    pub timestamp: u64,
    pub signature: Vec<u8>,
}

pub struct CryptoKeyPair {
    signing_key: SigningKey,
    pub verifying_key: VerifyingKey,
}

impl CryptoKeyPair {
    pub fn new() -> Self {
        let mut csprng = OsRng;
        let signing_key = SigningKey::generate(&mut csprng);
        let verifying_key = signing_key.verifying_key();
        Self { signing_key, verifying_key }
    }

    pub fn sign(&self, message: &[u8]) -> Signature {
        self.signing_key.sign(message)
    }

    pub fn verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> bool {
        if let (Ok(pk), Ok(sig)) = (
            VerifyingKey::from_bytes(public_key.try_into().unwrap()),
            Signature::from_slice(signature),
        ) {
            pk.verify(message, &sig).is_ok()
        } else {
            false
        }
    }

    pub fn public_key_bytes(&self) -> [u8; 32] {
        self.verifying_key.to_bytes()
    }
}
