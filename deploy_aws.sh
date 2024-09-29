#!/bin/bash

# Set variables
EB_APPLICATION_NAME="heart-disease-prediction"
EB_ENVIRONMENT_NAME="heart-disease-prediction-env"
EB_PLATFORM="python-3.8"
REGION="us-west-2"  # Change this to your preferred region

# Function to create necessary files
create_files() {
    # Check if model files exist
    if [ ! -f best_model.pkl ] || [ ! -f columns.pkl ]; then
        echo "Model files best_model.pkl and columns.pkl are required."
        exit 1
    fi

    # Create application.py
    cat << EOF > application.py
import os
import joblib
import numpy as np
from flask import Flask, request, jsonify

app = Flask(__name__)

# Load the model and columns
model = joblib.load('best_model.pkl')
X_train_columns = joblib.load('columns.pkl')

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.json
        input_data = np.array([data.get(col, 0) for col in X_train_columns]).reshape(1, -1)
        prediction = model.predict(input_data)
        return jsonify({'prediction': int(prediction[0])})
    except Exception as e:
        return jsonify({'error': str(e)}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
EOF

    # Create requirements.txt
    cat << EOF > requirements.txt
Flask==2.0.1
joblib==1.0.1
numpy==1.21.0
scikit-learn==0.24.2
gunicorn==20.1.0
EOF

    # Create Procfile
    echo "web: gunicorn application:app" > Procfile

    # Create .ebextensions directory and config file
    mkdir -p .ebextensions
    cat << EOF > .ebextensions/01_flask.config
option_settings:
  aws:elasticbeanstalk:container:python:
    WSGIPath: application:app
EOF

    echo "All necessary files created."
}

# Function to create and deploy the application
create_and_deploy() {
    # Create necessary files
    create_files

    # Initialize the Elastic Beanstalk application
    eb init $EB_APPLICATION_NAME --region $REGION --platform "$EB_PLATFORM"

    # Create the Elastic Beanstalk environment
    eb create $EB_ENVIRONMENT_NAME

    # Deploy the application
    eb deploy

    # Get the application URL
    APP_URL=$(eb status $EB_ENVIRONMENT_NAME | grep "CNAME:" | awk '{print $2}')
    echo "Application deployed. URL: http://$APP_URL"

    # Test the API
    echo "Testing the API..."
    RESPONSE=$(curl -s -X POST \
         -H "Content-Type: application/json" \
         -d '{
             "age": 63,
             "sex": 1,
             "cp": 3,
             "trestbps": 145,
             "chol": 233,
             "fbs": 1,
             "restecg": 0,
             "thalach": 150,
             "exang": 0,
             "oldpeak": 2.3,
             "slope": 0,
             "ca": 0,
             "thal": 1
         }' \
         http://$APP_URL/predict)

    echo "API Response: $RESPONSE"

    if [[ $RESPONSE == *"prediction"* ]]; then
        echo "Test passed successfully."
    else
        echo "Test failed. Please check the logs and the application."
        echo "You can use 'eb logs' to view the application logs."
    fi
}

# Function to delete the application and environment
delete_application() {
    # Terminate the environment
    eb terminate $EB_ENVIRONMENT_NAME --force

    # Delete the application
    aws elasticbeanstalk delete-application --application-name $EB_APPLICATION_NAME

    echo "Application and environment deleted."
}

# Main script
if [ "$1" = "create" ]; then
    create_and_deploy
elif [ "$1" = "delete" ]; then
    delete_application
else
    echo "Usage: $0 [create|delete]"
    exit 1
fi
