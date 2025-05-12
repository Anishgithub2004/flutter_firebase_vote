import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'ipfs_service.dart';

class BlockchainService {
  final String _baseUrl =
      'https://your-fabric-api-endpoint.com/api'; // Replace with your actual Fabric API endpoint
  final IPFSService _ipfsService = IPFSService();

  // Submit KYC data to the blockchain
  Future<Map<String, dynamic>> submitKYC(
    UserModel user, {
    String? aadharImageCID,
    String? panImageCID,
    String? voterIdImageCID,
  }) async {
    try {
      // Prepare KYC data for blockchain
      final Map<String, dynamic> kycData = {
        'userId': user.uid,
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'address': user.address,
        'aadharNumber': user.aadharNumber,
        'panNumber': user.panNumber,
        'voterIdNumber': user.voterIdNumber,
        'age': user.age,
        'gender': user.gender,
        'constituency': user.constituency,
        'documents': {
          'aadharCardCID': aadharImageCID,
          'panCardCID': panImageCID,
          'voterIdCID': voterIdImageCID,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Submit KYC data to blockchain
      final response = await http.post(
        Uri.parse('$_baseUrl/kyc/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(kycData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to submit KYC data: ${response.body}');
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      // Return the transaction ID and any other relevant data
      return {
        'success': true,
        'transactionId': result['transactionId'],
        'timestamp': result['timestamp'],
        'message': 'KYC data submitted successfully',
      };
    } catch (e) {
      print('Error submitting KYC data to blockchain: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Verify KYC status on the blockchain
  Future<Map<String, dynamic>> verifyKYC(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/kyc/verify/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to verify KYC status: ${response.body}');
      }

      final Map<String, dynamic> result = jsonDecode(response.body);
      return result;
    } catch (e) {
      print('Error verifying KYC status: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get KYC transaction history for a user
  Future<List<Map<String, dynamic>>> getKYCHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/kyc/history/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get KYC history: ${response.body}');
      }

      final List<dynamic> history = jsonDecode(response.body);
      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting KYC history: $e');
      return [];
    }
  }
}
