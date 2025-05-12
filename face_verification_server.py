from flask import Flask, request, jsonify
import cv2
import numpy as np
from pathlib import Path
import os
from motor.motor_asyncio import AsyncIOMotorClient
import base64
import logging
import asyncio
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = Flask(__name__)
UPLOAD_FOLDER = Path('uploads')
UPLOAD_FOLDER.mkdir(exist_ok=True)

# Add a test route
@app.route('/')
def test():
    return jsonify({
        'status': 'success',
        'message': 'Face verification server is running!',
        'endpoints': {
            'test': '/',
            'verify_face': '/verify_face',
            'detect_faces': '/detect_faces'
        }
    })

# MongoDB connection
try:
    # Create Motor client
    client = AsyncIOMotorClient(
        "mongodb+srv://anish444:e-votex@e-votex.nlfozfk.mongodb.net/E-voting?retryWrites=true&w=majority",
        tls=True,
        tlsAllowInvalidCertificates=True,
        serverSelectionTimeoutMS=5000,
        socketTimeoutMS=45000,
        connectTimeoutMS=10000,
        maxPoolSize=50,
        minPoolSize=10,
        maxIdleTimeMS=60000,
        waitQueueTimeoutMS=10000
    )
    
    # Get database
    db = client['E-voting']
    logger.info("Successfully connected to MongoDB Atlas with Motor")
except Exception as e:
    logger.error(f"Failed to connect to MongoDB Atlas: {e}")
    raise

# Load the face detection cascade
try:
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    logger.info("Successfully loaded face detection cascade")
except Exception as e:
    logger.error(f"Failed to load face detection cascade: {e}")
    raise

def save_face_image(face_image, user_id, source_type):
    try:
        # Save to uploads folder
        user_folder = UPLOAD_FOLDER / user_id
        user_folder.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'face_{source_type}_{timestamp}.jpg'
        filepath = user_folder / filename
        
        cv2.imwrite(str(filepath), face_image)
        logger.info(f"Saved face image to: {filepath}")
        
        # Convert to base64 for MongoDB
        _, buffer = cv2.imencode('.jpg', face_image)
        base64_image = base64.b64encode(buffer).decode('utf-8')
        
        # Save to MongoDB
        asyncio.run(db.face_images.insert_one({
            'userId': user_id,
            'faceImage': base64_image,
            'extractedFrom': source_type,
            'filePath': str(filepath),
            'timestamp': datetime.now(),
            'isVerified': False
        }))
        
        return str(filepath)
    except Exception as e:
        logger.error(f"Error saving face image: {e}")
        return None

def preprocess_image(image):
    try:
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        logger.debug("Successfully converted image to grayscale")
        
        # Resize image to a reasonable size while maintaining aspect ratio
        max_dimension = 500
        height, width = gray.shape[:2]
        if height > width:
            new_height = max_dimension
            new_width = int(width * (max_dimension / height))
        else:
            new_width = max_dimension
            new_height = int(height * (max_dimension / width))
        
        resized_image = cv2.resize(gray, (new_width, new_height))
        logger.debug(f"Successfully resized image to {new_width}x{new_height}")
        return resized_image
    except Exception as e:
        logger.error(f"Error in preprocess_image: {e}")
        return None

def detect_and_crop_face(image):
    try:
        # Detect faces in the image
        faces = face_cascade.detectMultiScale(
            image,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30)
        )
        
        logger.debug(f"Detected {len(faces)} faces in the image")
        
        if len(faces) == 0:
            logger.warning("No faces detected in the image")
            return None
        
        # Get the largest face (assuming it's the main subject)
        face = max(faces, key=lambda f: f[2] * f[3])
        x, y, w, h = face
        
        # Add some padding around the face
        padding = 20
        x = max(0, x - padding)
        y = max(0, y - padding)
        w = min(image.shape[1] - x, w + 2 * padding)
        h = min(image.shape[0] - y, h + 2 * padding)
        
        # Crop the face
        face_image = image[y:y+h, x:x+w]
        logger.debug(f"Successfully cropped face with dimensions {w}x{h}")
        return face_image
    except Exception as e:
        logger.error(f"Error in detect_and_crop_face: {e}")
        return None

def compare_faces(face1, face2):
    try:
        if face1 is None or face2 is None:
            logger.warning("One or both faces are None in comparison")
            return 0.0
        
        # Resize both faces to the same size
        face1 = cv2.resize(face1, (100, 100))
        face2 = cv2.resize(face2, (100, 100))
        
        # Calculate the absolute difference between the two faces
        diff = cv2.absdiff(face1, face2)
        
        # Calculate the mean difference
        mean_diff = np.mean(diff)
        
        # Convert to similarity score (higher is better)
        similarity = 1 - (mean_diff / 255.0)
        logger.debug(f"Face comparison similarity score: {similarity:.2f}")
        return similarity
    except Exception as e:
        logger.error(f"Error in compare_faces: {e}")
        return 0.0

async def get_voter_id_face(user_id):
    try:
        logger.info(f"Attempting to get ID document for user: {user_id}")
        
        # Get the document from the documents collection
        doc = await db.documents.find_one({
            'userId': user_id,
            'documentType': 'voter_id'
        })
        
        if not doc:
            logger.error(f"No voter ID document found for user: {user_id}")
            return None
            
        if 'file' not in doc:
            logger.error(f"No file data found in document for user: {user_id}")
            return None
        
        # Convert base64 to OpenCV image
        try:
            # Decode base64 string
            image_data = base64.b64decode(doc['file'])
            
            # Convert to numpy array
            nparr = np.frombuffer(image_data, np.uint8)
            
            # Decode image
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            logger.debug(f"Document image dimensions: {img.shape}")
            
            # Preprocess and detect face
            processed_image = preprocess_image(img)
            if processed_image is None:
                logger.error("Failed to preprocess document image")
                return None
                
            face_image = detect_and_crop_face(processed_image)
            if face_image is None:
                logger.error("Failed to detect face in document")
                return None
                
            # Save the extracted face
            save_face_image(face_image, user_id, 'voter_id')
                
            logger.info("Successfully extracted face from document")
            return face_image
            
        except Exception as e:
            logger.error(f"Error processing base64 image: {e}")
            return None
            
    except Exception as e:
        logger.error(f"Error in get_voter_id_face: {e}")
        return None

@app.route('/verify_face', methods=['POST'])
def verify_face():
    try:
        logger.info("Received face verification request")
        
        if 'image' not in request.files:
            logger.error("No image provided in request")
            return jsonify({'success': False, 'error': 'No image provided'})
        
        user_id = request.form.get('user_id')
        if not user_id:
            logger.error("No user ID provided in request")
            return jsonify({'success': False, 'error': 'No user ID provided'})
        
        logger.info(f"Processing verification for user: {user_id}")
        
        # Get the face from the voter's ID document
        logger.info(f"Attempting to extract face from voter ID document for user: {user_id}")
        id_face = asyncio.run(get_voter_id_face(user_id))
        if id_face is None:
            logger.error("Failed to get face from ID document")
            return jsonify({'success': False, 'error': 'Could not find or process ID document face'})
        logger.info("Successfully extracted face from voter ID document")
        
        # Process the uploaded live image
        file = request.files['image']
        img = cv2.imdecode(np.frombuffer(file.read(), np.uint8), cv2.IMREAD_COLOR)
        logger.debug(f"Live image dimensions: {img.shape}")
        
        # Preprocess and detect face
        logger.info("Processing live image for face detection")
        processed_image = preprocess_image(img)
        if processed_image is None:
            logger.error("Failed to preprocess live image")
            return jsonify({'success': False, 'error': 'Failed to process live image'})
            
        live_face = detect_and_crop_face(processed_image)
        if live_face is None:
            logger.error("Failed to detect face in live image")
            return jsonify({'success': False, 'error': 'No face detected in live image'})
        logger.info("Successfully detected face in live image")
        
        # Save the live face
        save_face_image(live_face, user_id, 'live')
        
        # Compare faces
        logger.info("Starting face comparison")
        similarity = compare_faces(id_face, live_face)
        logger.info(f"Face comparison complete. Similarity score: {similarity:.2f} ({(similarity * 100):.2f}%)")
        
        is_match = similarity >= 0.5  # Reduced threshold to 50%
        logger.info(f"Verification {'passed' if is_match else 'failed'} with threshold 0.5")
        
        # Update verification status in MongoDB
        if is_match:
            logger.info("Updating verification status in MongoDB")
            asyncio.run(db.face_images.update_many(
                {'userId': user_id},
                {'$set': {'isVerified': True}}
            ))
        
        return jsonify({
            'success': True,
            'match_percentage': float(similarity),
            'is_match': is_match,
            'message': f'Face match percentage: {similarity:.2%}'
        })
    except Exception as e:
        logger.error(f"Error in verify_face endpoint: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/detect_faces', methods=['POST'])
def detect_faces():
    try:
        logger.info("Received face detection request")
        
        if 'image' not in request.files:
            logger.error("No image provided in request")
            return jsonify({'success': False, 'error': 'No image provided'})
        
        # Process the uploaded image
        file = request.files['image']
        img = cv2.imdecode(np.frombuffer(file.read(), np.uint8), cv2.IMREAD_COLOR)
        logger.debug(f"Image dimensions: {img.shape}")
        
        # Convert to grayscale for face detection
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Detect faces with more lenient parameters
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,  # Reduced from 1.3
            minNeighbors=3,   # Reduced from 5
            minSize=(30, 30), # Reduced from (50, 50)
            flags=cv2.CASCADE_SCALE_IMAGE
        )
        
        logger.info(f"Detected {len(faces)} faces in the image")
        
        # Return results
        return jsonify({
            'success': True,
            'face_count': len(faces),
            'multiple_faces': len(faces) > 1,
            'message': f'Detected {len(faces)} face(s) in the image'
        })
    except Exception as e:
        logger.error(f"Error in detect_faces endpoint: {e}")
        return jsonify({'success': False, 'error': str(e)})

if __name__ == '__main__':
    print("Starting face verification server...")
    print(f"Server will run at http://192.168.0.111:5000")
    print("Press Ctrl+C to stop the server")
    try:
        app.run(host='192.168.0.111', port=5000, debug=True, use_reloader=False)
    except Exception as e:
        logger.error(f"Server error: {e}")
        raise 