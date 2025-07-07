# Production-Ready Reddit Video Automation Workflow

This is a production-ready n8n workflow that automatically creates social media videos from Reddit posts using AI tools.

## 🎯 What It Does

The workflow automatically:
1. **Scrapes Reddit posts** from specified subreddits
2. **Filters content** based on quality criteria (upvotes, comments, word count)
3. **Optimizes text** using local LLM (Ollama)
4. **Generates TTS audio** from the optimized text
5. **Creates video** by combining audio with stock footage
6. **Adds subtitles** using Whisper transcription
7. **Uploads to social media** platforms (YouTube, TikTok, Instagram)

## 🏗️ Architecture

### Core Components
- **n8n**: Workflow automation platform
- **Ollama**: Local LLM for text optimization
- **Qdrant**: Vector database for embeddings
- **PostgreSQL**: Primary database
- **Redis**: Caching and rate limiting
- **Nginx**: Reverse proxy with rate limiting
- **Prometheus + Grafana**: Monitoring (optional)

### Production Features
- ✅ **Error Handling**: Comprehensive error handling with retry logic
- ✅ **Security**: Input validation, rate limiting, secure credential management
- ✅ **Monitoring**: Health checks, logging, metrics collection
- ✅ **Scalability**: Resource limits, cleanup automation
- ✅ **Reliability**: Retry mechanisms, fallback options

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- At least 8GB RAM (16GB recommended)
- FFmpeg, curl, jq, bc installed in the container

### Installation

1. **Clone and setup**:
```bash
git clone <this-repository>
cd self-hosted-ai-starter-kit
cp .env.example .env
```

2. **Configure environment variables** in `.env`:
```bash
# Essential configurations
POSTGRES_PASSWORD=your-secure-password
N8N_ENCRYPTION_KEY=your-32-character-encryption-key
N8N_USER_MANAGEMENT_JWT_SECRET=your-32-character-jwt-secret

# Social media API keys
YOUTUBE_CLIENT_ID=your-youtube-client-id
YOUTUBE_CLIENT_SECRET=your-youtube-client-secret
TIKTOK_ACCESS_TOKEN=your-tiktok-access-token
INSTAGRAM_ACCESS_TOKEN=your-instagram-access-token
INSTAGRAM_ACCOUNT_ID=your-instagram-account-id
```

3. **Start the services**:
```bash
# For CPU-only setup
docker compose --profile cpu up -d

# For NVIDIA GPU setup
docker compose --profile gpu-nvidia up -d

# With monitoring
docker compose --profile cpu --profile monitoring up -d
```

4. **Setup production environment**:
```bash
docker exec -it n8n bash /app/scripts/setup_production.sh
```

5. **Access n8n**: Open http://localhost:5678

## 📋 Configuration

### Workflow Parameters

The workflow accepts these parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `subredditUrl` | `https://www.reddit.com/r/AmItheAsshole/hot.json?limit=100` | Reddit API URL |
| `minWords` | `300` | Minimum word count for posts |
| `maxWords` | `500` | Maximum word count for posts |
| `minUpvotes` | `1000` | Minimum upvotes required |
| `minComments` | `50` | Minimum comments required |
| `ollamaModel` | `mistral` | LLM model for text optimization |
| `ttsVoice` | `female` | TTS voice selection |
| `whisperModel` | `base.en` | Whisper model for transcription |
| `youtubePrivacy` | `private` | YouTube upload privacy |
| `stockVideoPathOrUrl` | (Pexels URL) | Stock video source |

### Security Configuration

Edit these in `.env`:
```bash
RATE_LIMIT_REQUESTS_PER_MINUTE=60
MAX_FILE_SIZE_MB=500
ALLOWED_DOMAINS=reddit.com,pexels.com,yourdomain.com
```

## 🔧 Production Setup

### SSL/HTTPS Setup

1. **Obtain SSL certificates** (Let's Encrypt recommended):
```bash
certbot certonly --standalone -d yourdomain.com
```

2. **Configure nginx** for HTTPS (uncomment HTTPS section in `nginx.conf`)

3. **Update Docker Compose** to mount certificates:
```yaml
nginx:
  volumes:
    - /etc/letsencrypt:/etc/nginx/ssl:ro
```

### API Credentials Setup

#### YouTube API:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project and enable YouTube Data API v3
3. Create OAuth 2.0 credentials
4. Add redirect URI: `http://yourdomain.com/rest/oauth2-credential/callback`

#### TikTok API:
1. Apply for [TikTok for Developers](https://developers.tiktok.com/)
2. Create an app and get access tokens
3. Note: TikTok API access is limited and requires approval

#### Instagram API:
1. Create a [Facebook App](https://developers.facebook.com/)
2. Add Instagram Basic Display product
3. Generate access tokens for Instagram Business accounts

### Monitoring Setup

1. **Enable monitoring profile**:
```bash
docker compose --profile monitoring up -d
```

2. **Access dashboards**:
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)

3. **Configure alerts** by setting webhook URLs in `.env`

## 🛠️ Maintenance

### Automated Maintenance

The setup includes automated cron jobs for:
- **Daily cleanup** of temporary files (2 AM)
- **Health monitoring** every 5 minutes
- **Log rotation** weekly

### Manual Maintenance

```bash
# Check system health
docker exec -it n8n /app/scripts/monitor_workflow.sh

# Clean up temporary files
docker exec -it n8n /app/scripts/cleanup_temp_files.sh

# Rotate logs
docker exec -it n8n /app/scripts/rotate_logs.sh

# View recent logs
docker logs n8n --tail 100
```

### Backup

```bash
# Backup volumes
docker run --rm -v n8n_storage:/data -v $(pwd):/backup alpine tar czf /backup/n8n_backup.tar.gz /data

# Backup database
docker exec postgres pg_dump -U n8n n8n > backup.sql
```

## 🔍 Troubleshooting

### Common Issues

1. **Ollama model not found**:
```bash
docker exec ollama ollama pull mistral
```

2. **FFmpeg not found**:
```bash
docker exec -it n8n apt-get update && apt-get install -y ffmpeg
```

3. **Permission errors**:
```bash
docker exec -it n8n chmod 755 /app/scripts/*.sh
```

4. **Rate limiting issues**:
   - Increase `RATE_LIMIT_REQUESTS_PER_MINUTE` in `.env`
   - Check nginx rate limiting configuration

### Logs Location

- **n8n logs**: `/var/log/n8n/`
- **Security logs**: `/var/log/n8n/security.log`
- **Container logs**: `docker logs <container-name>`

### Health Checks

```bash
# Check all services
docker ps

# Check n8n health
curl http://localhost:5678/healthz

# Check database connection
docker exec postgres pg_isready -U n8n -d n8n
```

## 📊 Performance Tuning

### Resource Optimization

1. **Adjust container limits** in `docker-compose.yml`
2. **Configure execution timeout**:
```yaml
environment:
  - N8N_EXECUTION_TIMEOUT=3600
```

3. **Enable Redis caching** for better performance

### Scaling

For high-volume processing:
1. **Use queue mode** for n8n
2. **Separate worker containers**
3. **Load balance** with multiple n8n instances
4. **External file storage** (S3, etc.)

## 🔒 Security Best Practices

1. **Change default passwords** in `.env`
2. **Use strong encryption keys** (32+ characters)
3. **Enable HTTPS** in production
4. **Regular security updates**:
```bash
docker compose pull
docker compose up -d
```

5. **Monitor failed login attempts**
6. **Backup encryption keys** securely

## 📈 Monitoring and Alerts

### Key Metrics to Monitor

- **Workflow execution success rate**
- **Disk space usage** (/tmp directory)
- **Memory and CPU usage**
- **API rate limit consumption**
- **Error rates** by component

### Alert Configuration

Set these environment variables:
```bash
ALERT_EMAIL=admin@yourdomain.com
WEBHOOK_URL=https://hooks.slack.com/your-webhook
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [n8n documentation](https://docs.n8n.io/)
- **Community**: Join the [n8n community forum](https://community.n8n.io/)
- **Issues**: Report bugs in the GitHub issues

---

**⚠️ Important Notes:**

1. **API Limits**: Social media APIs have strict rate limits and approval processes
2. **Content Policy**: Ensure content complies with platform guidelines
3. **Testing**: Always test with private uploads before going public
4. **Costs**: Monitor API usage costs for cloud services
5. **Legal**: Respect Reddit's API terms and content licenses