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
