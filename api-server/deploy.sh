#!/bin/bash

# Cloud Run deployment script for Sudoku Master API
# This script replaces App Engine Flex deployment

set -e

# Configuration
PROJECT_ID=${1:-"your-project-id"}
REGION=${2:-"us-central1"}
SERVICE_NAME="sudoku-master-api"

echo "🚀 Deploying Sudoku Master API to Cloud Run..."
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"

# Build and deploy using Cloud Build
echo "📦 Building and deploying with Cloud Build..."
gcloud builds submit --config cloudbuild.yaml --project=$PROJECT_ID

echo "✅ Deployment complete!"
echo "🌐 Your API is available at:"
gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)"

echo ""
echo "📋 Useful commands:"
echo "  View logs: gcloud run services logs read $SERVICE_NAME --region=$REGION --project=$PROJECT_ID"
echo "  Update service: gcloud run deploy $SERVICE_NAME --image gcr.io/$PROJECT_ID/$SERVICE_NAME:latest --region=$REGION --project=$PROJECT_ID"
echo "  Delete service: gcloud run services delete $SERVICE_NAME --region=$REGION --project=$PROJECT_ID"