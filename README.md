**InExistence** — it's a Ruby on Rails tool that checks whether Microsoft 365 emails exist by leveraging two little-known behaviors:

> You can watch the demo video on youtube [![Demo Video on Youtube](https://img.shields.io/badge/YouTube-Video-red?logo=youtube)](https://youtu.be/pGblC1MgJFM)

🔹 Tenant Discovery via SOAP
It uses a lightweight SOAP request to autodiscover-s.outlook.com to extract the M365 tenant name, allowing full automation without third-party dependencies.

🔹 OneDrive URL Probing
It checks availability via:
https://<tenant>-my.sharepoint.com/personal/<user>/_layouts/15/onedrive.aspx
A standard feature in M365 — not considered a vulnerability by Microsoft.

1 - Running with Docker (recommended):

> docker-compose up --build

docker-compose.yml
```yml
version: '3.8'

services:
  redis:
    image: redis:latest
    container_name: redis_container
    ports:
      - "6379:6379"

  app:
    image: johnermac/inexistence:slimmed
    container_name: in_existence_app
    environment:
      - RAILS_ENV=development
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - redis
    ports:
      - "3000:3000"

```


> Access: http://127.0.0.1:3000




💼 Use Cases:

    ✅ Threat Intelligence — Validate leaked or exposed emails
    ✅ Pentesting/Red Teaming — Confirm targets before phishing simulations
    ✅ Recon Automation — Feed validated emails into your attack surface mapping


⚙️ Built With:

Ruby on Rails • Redis • Sidekiq • Nokogiri • HTTPX


📦 In Summary:

    No authentication needed

    No brute-force

    Open Source

    Dockerized


📚 References:

    https://github.com/nyxgeek/o365recon

    https://github.com/Gerenios/AADInternals


⚠️ Disclaimer

*This tool is intended for educational and authorized security testing only.*
