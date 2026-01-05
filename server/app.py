import numpy as np
import tensorflow as tf
from flask import Flask, request, jsonify
from PIL import Image
import io
import base64

# Initialize Flask app
app = Flask(__name__)

# Load TensorFlow Lite model
interpreter = tf.lite.Interpreter(model_path="facenet.tflite")
interpreter.allocate_tensors()

# Get input and output details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

def preprocess_image(image_data):
    """
    Preprocess the input image for the FaceNet model.
    """
    image = Image.open(io.BytesIO(image_data)).convert('RGB')
    image = image.resize((160, 160))  # Resize to the model's input size
    image_array = np.asarray(image).astype(np.float32)
    image_array = (image_array - 127.5) / 127.5  # Normalize to [-1, 1]
    image_array = np.expand_dims(image_array, axis=0)  # Add batch dimension
    return image_array

def create_face_embedding(image_data):
    """
    Generate a face embedding for the given image data.
    """
    processed_image = preprocess_image(image_data)

    # Run the model
    interpreter.set_tensor(input_details[0]['index'], processed_image)
    interpreter.invoke()

    # Extract the embedding
    embedding = interpreter.get_tensor(output_details[0]['index'])
    return embedding.flatten().tolist()

@app.route('/generate-embedding', methods=['POST'])
def generate_embedding():
    """
    Endpoint to process an image and return its face embedding.
    """
    try:
        # Parse incoming JSON with base64-encoded image
        data = request.json
        if "image" not in data:
            return jsonify({"error": "Image data not provided"}), 400

        # Decode base64 image
        image_data = base64.b64decode(data["image"])
        
        # Generate embedding
        embedding = create_face_embedding(image_data)
        return jsonify({"embedding": embedding}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/')
def home():
    return "Face Embedding Generator API is running!"
    
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=80)
