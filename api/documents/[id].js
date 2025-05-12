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

    // Get document ID from URL parameters
    const documentId = req.params.id;
    console.log('Fetching document with ID:', documentId);

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
    const document = await Document.findById(documentId);
    
    if (!document) {
      console.error('Document not found:', documentId);
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