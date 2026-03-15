# Sanitizer Engine
the AI engine for Cyber job sanitization

## Run MySQL with Docker Compose

From the project root:

````bash
cd dev
docker compose down && docker compose up -d
````

Check container status:

````bash
docker compose ps
````

View logs:

````bash
docker compose logs -f db
````

Stop services:

````bash
docker compose down
````

## Database defaults

- **Host:** `127.0.0.1`
- **Port:** `3306`
- **Database:** `sanitizer_db`
- **User:** `user`
- **Password:** `password`
- **Root password:** `rootpassword`

### Troubleshooting: "Public Key Retrieval is not allowed"
If you encounter this error when connecting, append the following parameters to your JDBC connection string:
`?allowPublicKeyRetrieval=true&useSSL=false`

Example URL:
`jdbc:mysql://localhost:3306/sanitizer_db?allowPublicKeyRetrieval=true&useSSL=false`

The schema is initialized automatically from `dev/init.sql` on first startup.

---

## Kafka quick test (produce/consume)

From the project root:

````bash
cd dev
````
1) Start a consumer (terminal A)
````bash
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic systemlog_in \
  --from-beginning
`````
2) Start a producer (terminal B)
````bash
docker compose exec kafka kafka-console-producer \
  --bootstrap-server kafka:29092 \
  --topic systemlog_in  
`````
Type a message and press Enter (example: hello-systemlog-in).
You should see it appear in terminal A.

3) Exit
Producer/consumer: Ctrl + C
Stop all services when done: 
````bash
docker compose down
`````
