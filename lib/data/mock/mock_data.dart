import '../models/user_model.dart';
import '../models/child_model.dart';
import '../models/photo_model.dart';
import '../models/message_model.dart';
import '../models/class_model.dart';

/// Comprehensive mock data for KidConnect app
class MockData {
  MockData._();

  static final List<UserModel> teachers = [
    UserModel(
      id: 'teacher_1',
      name: 'Sarah Johnson',
      email: 'sarah.johnson@kidconnect.com',
      role: UserRole.teacher,
      phone: '+1 555-0101',
      createdAt: DateTime(2025, 1, 15),
    ),
    UserModel(
      id: 'teacher_2',
      name: 'Emily Chen',
      email: 'emily.chen@kidconnect.com',
      role: UserRole.teacher,
      phone: '+1 555-0102',
      createdAt: DateTime(2025, 3, 20),
    ),
  ];

  static final List<UserModel> parents = [
    UserModel(
      id: 'parent_1',
      name: 'Michael Davis',
      email: 'michael.davis@email.com',
      role: UserRole.parent,
      phone: '+1 555-0201',
      createdAt: DateTime(2025, 8, 10),
    ),
    UserModel(
      id: 'parent_ruthvi',
      name: 'Ruthvi Aisiri S',
      email: 'parent@kidconnect.com',
      role: UserRole.parent,
      phone: '9611777914',
      createdAt: DateTime(2025, 8, 15),
    ),
    UserModel(
      id: 'parent_priya',
      name: 'Priya Sharma',
      email: 'priya.sharma@email.com',
      role: UserRole.parent,
      phone: '9876543210',
      createdAt: DateTime(2025, 9, 1),
    ),
    UserModel(
      id: 'parent_rajesh',
      name: 'Rajesh Kumar',
      email: 'rajesh.kumar@email.com',
      role: UserRole.parent,
      phone: '9988776655',
      createdAt: DateTime(2025, 7, 20),
    ),
  ];

  static final List<ClassModel> classes = [
    const ClassModel(
      id: 'class_1',
      name: 'Sunshine Stars ☀️',
      teacherId: 'teacher_1',
      teacherName: 'Sarah Johnson',
      studentIds: ['child_1', 'child_2', 'child_3', 'child_ruthvi', 'child_aarav', 'child_ananya'],
      description: 'Ages 3-4, Morning session',
      schedule: 'Mon-Fri, 8:00 AM - 12:00 PM',
      capacity: 15,
    ),
  ];

  static final List<ChildModel> children = [
    ChildModel(
      id: 'child_1',
      name: 'Emma Davis',
      age: 4,
      classId: 'class_1',
      className: 'Sunshine Stars ☀️',
      parentId: 'parent_1',
      dateOfBirth: DateTime(2022, 3, 15),
      enrollmentDate: DateTime(2025, 8, 10),
      hasFaceProfile: true,
      enrolledFaceCount: 3,
    ),
    ChildModel(
      id: 'child_2',
      name: 'Liam Wilson',
      age: 3,
      classId: 'class_1',
      className: 'Sunshine Stars ☀️',
      parentId: 'parent_2',
      dateOfBirth: DateTime(2023, 1, 8),
      enrollmentDate: DateTime(2025, 9, 5),
    ),
    ChildModel(
      id: 'child_3',
      name: 'Sophia Martinez',
      age: 4,
      classId: 'class_1',
      className: 'Sunshine Stars ☀️',
      parentId: 'parent_3',
      dateOfBirth: DateTime(2022, 7, 22),
      enrollmentDate: DateTime(2025, 7, 22),
    ),
    ChildModel(
      id: 'child_ruthvi',
      name: 'Ruthvi Aisiri S',
      age: 4,
      classId: 'class_1',
      className: 'Sunshine Stars ☀️',
      parentId: 'parent_ruthvi',
      dateOfBirth: DateTime(2022, 8, 10),
      enrollmentDate: DateTime(2025, 8, 15),
      hasFaceProfile: true,
      enrolledFaceCount: 4,
    ),
    ChildModel(
      id: 'child_aarav',
      name: 'Aarav Sharma',
      age: 3,
      classId: 'class_1',
      className: 'Sunshine Stars ☀️',
      parentId: 'parent_priya',
      dateOfBirth: DateTime(2023, 2, 14),
      enrollmentDate: DateTime(2025, 9, 1),
    ),
    ChildModel(
      id: 'child_ananya',
      name: 'Ananya Kumar',
      age: 4,
      classId: 'class_1',
      className: 'Sunshine Stars ☀️',
      parentId: 'parent_rajesh',
      dateOfBirth: DateTime(2022, 11, 5),
      enrollmentDate: DateTime(2025, 7, 20),
      hasFaceProfile: true,
      enrolledFaceCount: 2,
    ),
  ];

  static final List<PhotoModel> photos = [
    PhotoModel(
      id: 'photo_1',
      url: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f',
      ),
      caption: 'Emma\'s beautiful rainbow painting! 🌈',
      childIds: ['child_1'],
      aiDetections: [
        const FaceDetection(childId: 'child_1', confidence: 0.98),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(hours: 2)),
      tags: ['art', 'painting', 'rainbow'],
    ),
    PhotoModel(
      id: 'photo_2',
      url: 'https://images.unsplash.com/photo-1560421683-6856ea585c78?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1560421683-6856ea585c78?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1560421683-6856ea585c78?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1560421683-6856ea585c78',
      ),
      caption: 'Group art session — everyone was so creative!',
      childIds: ['child_1', 'child_2'],
      aiDetections: [
        const FaceDetection(childId: 'child_1', confidence: 0.95),
        const FaceDetection(childId: 'child_2', confidence: 0.92),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(hours: 2)),
      tags: ['art', 'group', 'creative'],
    ),
    PhotoModel(
      id: 'photo_8',
      url: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d',
      ),
      caption: 'Music time with tambourines! 🎵',
      childIds: ['child_1', 'child_3'],
      aiDetections: [
        const FaceDetection(childId: 'child_1', confidence: 0.96),
        const FaceDetection(childId: 'child_3', confidence: 0.89),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(hours: 5)),
      tags: ['music', 'instruments', 'fun'],
    ),
    PhotoModel(
      id: 'photo_4',
      url: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c',
      ),
      caption: 'Story time with The Hungry Caterpillar 📖',
      childIds: ['child_1'],
      aiDetections: [
        const FaceDetection(childId: 'child_1', confidence: 0.88),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(days: 2)),
      tags: ['reading', 'story', 'book'],
    ),
    PhotoModel(
      id: 'photo_9',
      url: 'https://images.unsplash.com/photo-1472162072942-cd5147eb3902?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1472162072942-cd5147eb3902?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1472162072942-cd5147eb3902?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1472162072942-cd5147eb3902',
      ),
      caption: 'Sunny day playground time ☀️',
      childIds: ['child_1', 'child_2'],
      aiDetections: [
        const FaceDetection(childId: 'child_1', confidence: 0.92),
        const FaceDetection(childId: 'child_2', confidence: 0.90),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(days: 6)),
      tags: ['outdoor', 'playground', 'sunny'],
    ),
    PhotoModel(
      id: 'photo_12',
      url: 'https://images.unsplash.com/photo-1535572290543-960a8046f5af?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1535572290543-960a8046f5af?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1535572290543-960a8046f5af?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1535572290543-960a8046f5af',
      ),
      caption: 'Yoga poses — tree and cat! 🧘',
      childIds: ['child_1'],
      aiDetections: [
        const FaceDetection(childId: 'child_1', confidence: 0.94),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(days: 6)),
      tags: ['yoga', 'exercise', 'balance'],
    ),
    // Ruthvi-specific photos
    PhotoModel(
      id: 'photo_ruthvi_1',
      url: 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9',
      ),
      caption: 'Ruthvi building a tall tower! 🏗️',
      childIds: ['child_ruthvi'],
      aiDetections: [
        const FaceDetection(childId: 'child_ruthvi', confidence: 0.97),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(hours: 1)),
      tags: ['blocks', 'building', 'play'],
    ),
    PhotoModel(
      id: 'photo_ruthvi_2',
      url: 'https://images.unsplash.com/photo-1596464716127-f2a82984de30?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1596464716127-f2a82984de30?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1596464716127-f2a82984de30?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1596464716127-f2a82984de30',
      ),
      caption: 'Ruthvi painting with watercolors 🎨',
      childIds: ['child_ruthvi'],
      aiDetections: [
        const FaceDetection(childId: 'child_ruthvi', confidence: 0.95),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(hours: 3)),
      tags: ['art', 'painting', 'creative'],
    ),
    PhotoModel(
      id: 'photo_ruthvi_3',
      url: 'https://images.unsplash.com/photo-1516627145497-ae6968895b74?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1516627145497-ae6968895b74?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1516627145497-ae6968895b74?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1516627145497-ae6968895b74',
      ),
      caption: 'Reading time — Ruthvi loves books! 📚',
      childIds: ['child_ruthvi'],
      aiDetections: [
        const FaceDetection(childId: 'child_ruthvi', confidence: 0.93),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(days: 1)),
      tags: ['reading', 'books', 'learning'],
    ),
    PhotoModel(
      id: 'photo_group_ruthvi',
      url: 'https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=400',
      resolutions: const PhotoResolutions(
        thumbnail: 'https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=200&q=60',
        optimized: 'https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=800&q=80',
        original: 'https://images.unsplash.com/photo-1545558014-8692077e9b5c',
      ),
      caption: 'Group snack time — Ruthvi sharing with friends 🍎',
      childIds: ['child_ruthvi', 'child_2'],
      aiDetections: [
        const FaceDetection(childId: 'child_ruthvi', confidence: 0.91),
        const FaceDetection(childId: 'child_2', confidence: 0.90),
      ],
      uploadedBy: 'teacher_1',
      uploadDate: DateTime.now().subtract(const Duration(days: 2)),
      tags: ['snack', 'sharing', 'friends'],
    ),
  ];

  static final List<MessageModel> messages = [
    MessageModel(
      id: 'msg_3',
      senderId: 'teacher_1',
      receiverId: 'parent_1',
      senderName: 'Sarah Johnson',
      content: 'I\'ve uploaded some photos from today\'s activities to the gallery. You can check them out anytime!',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
    ),
  ];

  static List<ConversationModel> getConversationsForUser(String userId) {
    if (userId == 'parent_1') {
      return [
        ConversationModel(
          id: 'conv_1',
          otherUserId: 'teacher_1',
          otherUserName: 'Sarah Johnson',
          lastMessage: 'I\'ve uploaded some photos from today\'s activities to the gallery.',
          lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
          unreadCount: 1,
          isOnline: true,
        ),
      ];
    }
    return [];
  }

  static ChildModel? getChildById(String id) {
    try {
      return children.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static UserModel? getUserById(String id) {
    try {
      return [...teachers, ...parents].firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<ChildModel> getChildrenForParent(String parentId) {
    return children.where((c) => c.parentId == parentId).toList();
  }

  static UserModel? getParentByPhone(String phone) {
    try {
      return parents.firstWhere((p) => p.phone == phone);
    } catch (_) {
      return null;
    }
  }

  static List<PhotoModel> getPhotosForChild(String childId) {
    return photos.where((p) => p.containsChild(childId)).toList();
  }

  static List<MessageModel> getMessagesBetween(String userId1, String userId2) {
    return messages
        .where((m) =>
            (m.senderId == userId1 && m.receiverId == userId2) ||
            (m.senderId == userId2 && m.receiverId == userId1))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
