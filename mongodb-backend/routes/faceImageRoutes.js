const express = require('express');
const router = express.Router();
const { FaceImage } = require('../models/schemas');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const userId = req.body.userId;
    const dir = path.join(__dirname, '../../uploads/faces', userId);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const timestamp = Date.now();
    cb(null, `${timestamp}-${file.originalname}`);
  }
});

const upload = multer({ storage: storage });

// Save face image
router.post('/save', upload.single('faceImage'), async (req, res) => {
  try {
    const { userId, extractedFrom } = req.body;
    const filePath = req.file.path;
    
    // Read the image file and convert to base64
    const imageBuffer = fs.readFileSync(filePath);
    const base64Image = imageBuffer.toString('base64');

    const faceImage = new FaceImage({
      userId,
      faceImage: base64Image,
      extractedFrom,
      filePath,
      isVerified: false
    });

    await faceImage.save();
    res.status(201).json({ message: 'Face image saved successfully', faceImage });
  } catch (error) {
    console.error('Error saving face image:', error);
    res.status(500).json({ error: 'Failed to save face image' });
  }
});

// Get face images for a user
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log(`Checking face images for user: ${userId}`);
    
    const faceImages = await FaceImage.find({ userId });
    console.log(`Found ${faceImages.length} face images for user ${userId}`);
    
    if (faceImages.length === 0) {
      console.log('No face images found in database');
      return res.status(404).json({ 
        error: 'No face images found',
        message: 'Please register your face first'
      });
    }
    
    res.json(faceImages);
  } catch (error) {
    console.error('Error getting face images:', error);
    res.status(500).json({ error: 'Failed to get face images' });
  }
});

// Update verification status
router.patch('/:id/verify', async (req, res) => {
  try {
    const { id } = req.params;
    const { isVerified } = req.body;
    
    const faceImage = await FaceImage.findByIdAndUpdate(
      id,
      { isVerified },
      { new: true }
    );

    if (!faceImage) {
      return res.status(404).json({ error: 'Face image not found' });
    }

    res.json(faceImage);
  } catch (error) {
    console.error('Error updating verification status:', error);
    res.status(500).json({ error: 'Failed to update verification status' });
  }
});

// Delete face image
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const faceImage = await FaceImage.findById(id);

    if (!faceImage) {
      return res.status(404).json({ error: 'Face image not found' });
    }

    // Delete the file from the filesystem
    if (fs.existsSync(faceImage.filePath)) {
      fs.unlinkSync(faceImage.filePath);
    }

    await FaceImage.findByIdAndDelete(id);
    res.json({ message: 'Face image deleted successfully' });
  } catch (error) {
    console.error('Error deleting face image:', error);
    res.status(500).json({ error: 'Failed to delete face image' });
  }
});

module.exports = router; 