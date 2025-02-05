#!/bin/bash

# 设置 didkit 路径
DIDKIT="/Users/yushihang/Downloads/didkit-main/target/debug/didkit"

# 创建工作目录
rm -rf test
mkdir -p test
cd test

echo "1. 生成 Issuer 密钥..."
$DIDKIT key generate ed25519 > issuer_key.jwk
ISSUER_DID=$($DIDKIT key-to-did key -k issuer_key.jwk)
echo $ISSUER_DID > issuer_did.txt
echo "Issuer DID: $ISSUER_DID"
echo

echo "2. 生成 Holder 密钥..."
$DIDKIT key generate ed25519 > holder_key.jwk
HOLDER_DID=$($DIDKIT key-to-did key -k holder_key.jwk)
echo $HOLDER_DID > holder_did.txt
echo "Holder DID: $HOLDER_DID"
echo

echo "3. 创建凭证模板..."
cat > credential.json << EOF
{
  "@context": [
    "https://www.w3.org/2018/credentials/v1",
    {
      "WorkProofCredential": "https://example.com/WorkProofCredential",
      "proofOfWork": "https://example.com/vocab#proofOfWork",
      "domain": "https://example.com/vocab#domain",
      "uuid": "https://example.com/vocab#uuid",
      "timestamp": "https://example.com/vocab#timestamp"
    }
  ],
  "type": ["VerifiableCredential", "WorkProofCredential"],
  "issuer": {
    "id": "${ISSUER_DID}"
  },
  "issuanceDate": "2025-02-05T09:59:26Z",
  "credentialSubject": {
    "id": "${HOLDER_DID}",
    "proofOfWork": 42,
    "domain": "example.com",
    "uuid": "0CF7B336-AF4F-4A55-872E-D29EAF4BF082",
    "timestamp": "2025-02-05T09:59:26Z"
  }
}
EOF
echo

echo "4. 签发 VC..."
$DIDKIT vc-issue-credential \
  -k issuer_key.jwk \
  -p assertionMethod \
  < credential.json > signed_credential.json
echo

echo "5. 验证 VC..."
$DIDKIT vc-verify-credential \
  --verification-method "${ISSUER_DID}#${ISSUER_DID}" \
  --proof-purpose assertionMethod \
  < signed_credential.json
echo
echo

echo "6. 创建 VP 模板..."
cat > presentation.json << EOF
{
  "@context": ["https://www.w3.org/2018/credentials/v1"],
  "type": ["VerifiablePresentation"],
  "holder": "${HOLDER_DID}",
  "verifiableCredential": [$(cat signed_credential.json)]
}
EOF
echo

echo "7. 签发 VP..."
$DIDKIT vc-issue-presentation \
  -k holder_key.jwk \
  -p authentication \
  < presentation.json > signed_presentation.json
echo

echo "8. 验证 VP..."
$DIDKIT vc-verify-presentation \
  --verification-method "${HOLDER_DID}#${HOLDER_DID}" \
  --proof-purpose authentication \
  < signed_presentation.json
echo

