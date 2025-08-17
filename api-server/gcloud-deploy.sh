#!/bin/bash

# Alternative deployment script using gcloud run deploy directly
# This is simpler than Cloud Build for quick deployments

set -e

# Configuration
PROJECT_ID=${1:-"your-project-id"}
REGION=${2:-"us-central1"}
SERVICE_NAME="sudoku-master-api"

echo "🚀 Deploying Sudoku Master API to Cloud Run (direct deployment)..."
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"

# Deploy directly to Cloud Run
echo "📦 Deploying from source..."
gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --project $PROJECT_ID \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 100 \
  --concurrency 80 \
  --timeout 300

echo "✅ Deployment complete!"
echo "🌐 Your API is available at:"
gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)"