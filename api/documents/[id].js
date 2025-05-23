const mongoose = require('mongoose');

// MongoDB Schema definition
const documentSchema = new mongoose.Schema({
  file: String,
  documentType: String,
  userId: String,
  fileName: String,
  fileSize: Number,
  mimeType: String,
  uploadedAt: Date
});

// Create model
const Document = mongoose.model('Document', documentSchema);

// MongoDB connection handler
const connectDB = async () => {
  try {
    console.log('Attempting to connect to MongoDB...');
    console.log('MongoDB URI:', process.env.MONGODB_URI ? 'URI is set' : 'URI is not set');
    
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGODB_URI, {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        serverSelectionTimeoutMS: 30000,
        socketTimeoutMS: 45000,
        connectTimeoutMS: 30000,
        maxPoolSize: 10,
        minPoolSize: 5,
        maxIdleTimeMS: 30000,
        waitQueueTimeoutMS: 30000,
        retryWrites: true,
        w: 'majority'
      });
      console.log('Connected to MongoDB successfully');
    } else {
      console.log('Already connected to MongoDB');
    }
  } catch (error) {
    console.error('MongoDB connection error:', error);
    throw error;
  }
};

module.exports = async function handler(req, res) {
  try {
    console.log('API request received:', {
      method: req.method,
      url: req.url,
      params: req.params,
      query: req.query
    });

    // Connect to MongoDB
    await connectDB();

    if (req.method !== 'GET') {
      return res.status(405).json({ 
        success: false,
        error: 'Method not allowed' 
      });
    }

    // Extract document ID from URL path
    const urlParts = req.url.split('/');
    const documentId = urlParts[urlParts.length - 1];
    console.log('Extracted document ID from URL:', documentId);

    if (!documentId) {
      console.error('No document ID provided');
      return res.status(400).json({
        success: false,
        error: 'Document ID is required'
      });
    }

    // Validate MongoDB ObjectId format
    if (!mongoose.Types.ObjectId.isValid(documentId)) {
      console.error('Invalid document ID format:', documentId);
      return res.status(400).json({
        success: false,
        error: 'Invalid document ID format'
      });
    }

    console.log('Searching for document in MongoDB...');
    
    // First, check if the collection exists and has documents
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Available collections:', collections.map(c => c.name));
    
    const documentCount = await Document.countDocuments();
    console.log('Total documents in collection:', documentCount);
    
    // Try to find the document
    const document = await Document.findById(documentId);
    
    if (!document) {
      console.error('Document not found:', documentId);
      // List a few documents to help debug
      const sampleDocs = await Document.find().limit(3);
      console.log('Sample documents in collection:', sampleDocs.map(doc => ({
        id: doc._id,
        type: doc.documentType,
        fileName: doc.fileName
      })));
      return res.status(404).json({ 
        success: false,
        error: 'Document not found' 
      });
    }

    console.log('Document found:', {
      id: document._id,
      type: document.documentType,
      fileName: document.fileName,
      hasFile: !!document.file
    });

    // Ensure all required fields are present
    const response = {
      success: true,
      document: {
        id: document._id.toString(),
        documentType: document.documentType || '',
        userId: document.userId || '',
        fileName: document.fileName || '',
        fileSize: document.fileSize || 0,
        mimeType: document.mimeType || '',
        uploadedAt: document.uploadedAt || new Date(),
        file: document.file || ''
      }
    };

    console.log('Sending response:', {
      success: response.success,
      documentId: response.document.id,
      fileName: response.document.fileName,
      hasFile: !!response.document.file
    });

    res.json(response);
  } catch (error) {
    console.error('Error fetching document:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch document',
      details: error.message 
    });
  }
} 