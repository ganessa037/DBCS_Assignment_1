# DBCS Assignment 2 - AWS Deployment

## Docker

### Build the image
```bash
docker build -t dbcs-app .
```

### Run the container
```bash
docker run -p 5000:5000 dbcs-app
```

### Run with environment variables
```bash
docker run -p 5000:5000 \
  -e DB_SERVER=your-server \
  -e DB_NAME=your-db \
  -e DB_USER=your-user \
  -e DB_PASSWORD=your-password \
  dbcs-app
```

## GitHub Actions Workflow

The `.github/workflows/deploy.yaml` handles automated deployment to AWS.

### Required GitHub Secrets

Configure these secrets in your repository settings (`Settings > Secrets and variables > Actions`):

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_REGION` | AWS region (e.g., `us-east-1`) |

### Workflow Configuration

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```
