import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gig_hub/src/Data/models/group_chat.dart';

void main() {
  group('GroupChat Model', () {
    late DateTime testDate;
    late DateTime deleteDate;

    setUp(() {
      testDate = DateTime(2024, 1, 1, 12, 0, 0);
      deleteDate = DateTime(2024, 1, 3, 12, 0, 0);
    });

    test('should create GroupChat with required fields', () {
      final groupChat = GroupChat(
        id: 'chat-id',
        raveId: 'rave-id',
        name: 'Test Chat',
        memberIds: ['user1', 'user2'],
        createdAt: testDate,
      );

      expect(groupChat.id, 'chat-id');
      expect(groupChat.raveId, 'rave-id');
      expect(groupChat.name, 'Test Chat');
      expect(groupChat.memberIds, ['user1', 'user2']);
      expect(groupChat.createdAt, testDate);
      expect(groupChat.isActive, true);
      expect(groupChat.lastMessage, isNull);
      expect(groupChat.autoDeleteAt, isNull);
      expect(groupChat.imageUrl, isNull);
    });

    test('should create GroupChat with all optional fields', () {
      final groupChat = GroupChat(
        id: 'chat-id',
        raveId: 'rave-id',
        name: 'Test Chat',
        memberIds: ['user1', 'user2'],
        createdAt: testDate,
        lastMessage: 'Hello world',
        lastMessageSenderId: 'user1',
        lastMessageTimestamp: testDate,
        autoDeleteAt: deleteDate,
        isActive: false,
        imageUrl: 'https://example.com/image.jpg',
      );

      expect(groupChat.lastMessage, 'Hello world');
      expect(groupChat.lastMessageSenderId, 'user1');
      expect(groupChat.lastMessageTimestamp, testDate);
      expect(groupChat.autoDeleteAt, deleteDate);
      expect(groupChat.isActive, false);
      expect(groupChat.imageUrl, 'https://example.com/image.jpg');
    });

    test('should serialize to JSON correctly', () {
      final groupChat = GroupChat(
        id: 'chat-id',
        raveId: 'rave-id',
        name: 'Test Chat',
        memberIds: ['user1', 'user2'],
        createdAt: testDate,
        lastMessage: 'Hello world',
        lastMessageSenderId: 'user1',
        lastMessageTimestamp: testDate,
        autoDeleteAt: deleteDate,
        isActive: false,
        imageUrl: 'https://example.com/image.jpg',
      );

      final json = groupChat.toJson();

      expect(json['raveId'], 'rave-id');
      expect(json['name'], 'Test Chat');
      expect(json['memberIds'], ['user1', 'user2']);
      expect(json['lastMessage'], 'Hello world');
      expect(json['lastMessageSenderId'], 'user1');
      expect(json['lastMessageTimestamp'], isA<Timestamp>());
      expect(json['createdAt'], isA<Timestamp>());
      expect(json['autoDeleteAt'], isA<Timestamp>());
      expect(json['isActive'], false);
      expect(json['imageUrl'], 'https://example.com/image.jpg');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'raveId': 'rave-id',
        'name': 'Test Chat',
        'memberIds': ['user1', 'user2'],
        'lastMessage': 'Hello world',
        'lastMessageSenderId': 'user1',
        'lastMessageTimestamp': Timestamp.fromDate(testDate),
        'createdAt': Timestamp.fromDate(testDate),
        'autoDeleteAt': Timestamp.fromDate(deleteDate),
        'isActive': false,
        'imageUrl': 'https://example.com/image.jpg',
      };

      final groupChat = GroupChat.fromJson('chat-id', json);

      expect(groupChat.id, 'chat-id');
      expect(groupChat.raveId, 'rave-id');
      expect(groupChat.name, 'Test Chat');
      expect(groupChat.memberIds, ['user1', 'user2']);
      expect(groupChat.lastMessage, 'Hello world');
      expect(groupChat.lastMessageSenderId, 'user1');
      expect(groupChat.lastMessageTimestamp, testDate);
      expect(groupChat.createdAt, testDate);
      expect(groupChat.autoDeleteAt, deleteDate);
      expect(groupChat.isActive, false);
      expect(groupChat.imageUrl, 'https://example.com/image.jpg');
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'raveId': 'rave-id',
        'name': 'Test Chat',
        'memberIds': ['user1', 'user2'],
        'createdAt': Timestamp.fromDate(testDate),
      };

      final groupChat = GroupChat.fromJson('chat-id', json);

      expect(groupChat.lastMessage, isNull);
      expect(groupChat.lastMessageSenderId, isNull);
      expect(groupChat.lastMessageTimestamp, isNull);
      expect(groupChat.autoDeleteAt, isNull);
      expect(groupChat.isActive, true); // Default value
      expect(groupChat.imageUrl, isNull);
    });

    test('should create copy with updated fields', () {
      final originalChat = GroupChat(
        id: 'chat-id',
        raveId: 'rave-id',
        name: 'Original Chat',
        memberIds: ['user1'],
        createdAt: testDate,
        isActive: true,
      );

      final updatedChat = originalChat.copyWith(
        name: 'Updated Chat',
        memberIds: ['user1', 'user2'],
        lastMessage: 'New message',
        isActive: false,
      );

      // Original should remain unchanged
      expect(originalChat.name, 'Original Chat');
      expect(originalChat.memberIds, ['user1']);
      expect(originalChat.lastMessage, isNull);
      expect(originalChat.isActive, true);

      // Updated should have new values
      expect(updatedChat.id, 'chat-id'); // Unchanged
      expect(updatedChat.raveId, 'rave-id'); // Unchanged
      expect(updatedChat.name, 'Updated Chat'); // Changed
      expect(updatedChat.memberIds, ['user1', 'user2']); // Changed
      expect(updatedChat.lastMessage, 'New message'); // Changed
      expect(updatedChat.isActive, false); // Changed
      expect(updatedChat.createdAt, testDate); // Unchanged
    });

    test('should create copy with no changes when no parameters provided', () {
      final originalChat = GroupChat(
        id: 'chat-id',
        raveId: 'rave-id',
        name: 'Test Chat',
        memberIds: ['user1'],
        createdAt: testDate,
      );

      final copiedChat = originalChat.copyWith();

      expect(copiedChat.id, originalChat.id);
      expect(copiedChat.raveId, originalChat.raveId);
      expect(copiedChat.name, originalChat.name);
      expect(copiedChat.memberIds, originalChat.memberIds);
      expect(copiedChat.createdAt, originalChat.createdAt);
      expect(copiedChat.isActive, originalChat.isActive);
    });
  });
}
