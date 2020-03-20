import Config

config(:gcp_secret_provider,
  http: GcpSecretProvider.MockHttp,
  goth: GcpSecretProvider.MockGoth,
  service_account: ~S({
    "project_id": "PROJECT_ID",
    "private_key": "MOCK_KEY",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/my_lovely_app.iam.gserviceaccount.com"
  })
)

config(:goth, json: ~S({
    "project_id": "PROJECT_ID",
    "private_key": "MOCK_KEY",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/my_lovely_app.iam.gserviceaccount.com"
  }))
