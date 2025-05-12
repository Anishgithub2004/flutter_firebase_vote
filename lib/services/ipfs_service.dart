import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

class IPFSService {
  // Use Infura IPFS gateway - replace with your own API key and secret
  final String _ipfsApiUrl = 'https://ipfs.infura.io:5001/api/v0';
  final String _ipfsGatewayUrl = 'https://ipfs.infura.io/ipfs';

  // Project ID and secret for Infura - replace with your own
  final String _projectId = 'your_infura_project_id';
  final String _projectSecret = 'your_infura_project_secret';

  // Basic authentication headers
  Map<String, String> get _headers {
    final auth =
        'Basic ${base64Encode(utf8.encode('$_projectId:$_projectSecret'))}';
    return {
      'Authorization': auth,
    };
  }

  // Upload a file to IPFS
  Future<String> uploadFile(File file) async {
    try {
      // Create a multipart request
      final request =
          http.MultipartRequest('POST', Uri.parse('$_ipfsApiUrl/add'));

      // Add authorization headers
      request.headers.addAll(_headers);

      // Determine the mime type
      final fileExtension = path.extension(file.path).toLowerCase();
      final mimeType = _getMimeType(fileExtension);

      // Add the file to the request
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: path.basename(file.path),
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      // Send the request
      final response = await request.send();

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        throw Exception('Failed to upload file to IPFS: $responseBody');
      }

      // Get the response
      final responseString = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseString);

      // Return the IPFS hash (CID)
      return jsonResponse['Hash'];
    } catch (e) {
      print('Error uploading file to IPFS: $e');
      rethrow;
    }
  }

  // Get a file from IPFS using the hash
  String getIpfsUrl(String hash) {
    return '$_ipfsGatewayUrl/$hash';
  }

  // Helper method to determine mime type from file extension
  String _getMimeType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
