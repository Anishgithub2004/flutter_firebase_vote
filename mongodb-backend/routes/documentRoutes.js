const express = require('express');
const router = express.Router();
const { Document } = require('../models/schemas');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { MongoClient } = require('mongodb');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, '../../uploads/documents');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Get all documents for a specific user
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('Fetching documents for user:', userId);
    
    const documents = await Document.find({ userId });
    console.log('Found documents:', documents);
    
    res.json(documents);
  } catch (error) {
    console.error('Error fetching user documents:', error);
    res.status(500).json({ error: 'Failed to fetch user documents' });
  }
});

// Get a single document by ID
router.get('/:documentId', async (req, res) => {
  try {
    const { documentId } = req.params;
    console.log('Fetching document with ID:', documentId);
    
    // First try to find by ID
    let document = await Document.findById(documentId);
    
    // If not found by ID, try to find by file name
    if (!document) {
      document = await Document.findOne({ fileName: documentId });
    }
    
    if (!document) {
      console.log('Document not found with ID:', documentId);
      return res.status(404).json({ error: 'Document not found' });
    }
    
    console.log('Found document:', document);
    res.json(document);
  } catch (error) {
    console.error('Error fetching document:', error);
    res.status(500).json({ error: 'Failed to fetch document' });
  }
});

// Verify KYC documents for a user
router.get('/verify/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log(`Verifying KYC documents for user: ${userId}`);

    // Required document types - updated to match schema
    const requiredDocs = ['aadhar_card', 'pan_card', 'voter_id'];
    
    // Get all documents for the user
    const documents = await Document.find({ userId });
    console.log(`Found ${documents.length} documents for user ${userId}`);

    // Check if all required documents are present
    const missingDocs = requiredDocs.filter(docType => 
      !documents.some(doc => doc.documentType === docType)
    );

    if (missingDocs.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Missing required KYC documents',
        missingDocuments: missingDocs
      });
    }

    // Check if all documents are valid
    const invalidDocs = documents.filter(doc => 
      !doc.file || !doc.fileSize || doc.fileSize === 0
    );

    if (invalidDocs.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Some documents are invalid',
        invalidDocuments: invalidDocs.map(doc => doc.documentType)
      });
    }

    // All checks passed
    return res.status(200).json({
      success: true,
      message: 'All KYC documents verified successfully',
      documents: documents.map(doc => ({
        documentType: doc.documentType,
        fileName: doc.fileName,
        uploadedAt: doc.uploadedAt
      }))
    });

  } catch (error) {
    console.error('Error verifying KYC documents:', error);
    return res.status(500).json({
      success: false,
      message: 'Error verifying KYC documents',
      error: error.message
    });
  }
});

module.exports = router; 