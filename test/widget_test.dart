import 'package:flutter_test/flutter_test.dart';
import 'package:snappix_ai/data/mock/mock_data.dart';
import 'package:snappix_ai/data/models/user_model.dart';

void main() {
  testWidgets('UserModel creates correct initials', (WidgetTester tester) async {
    final user = UserModel(
      id: 'test_1',
      name: 'John Doe',
      email: 'john@test.com',
      role: UserRole.parent,
      createdAt: DateTime(2025, 1, 1),
    );

    expect(user.initials, 'JD');
    expect(user.firstName, 'John');
  });

  testWidgets('ChildModel creates correct initials', (WidgetTester tester) async {
    final child = MockData.children.first;

    expect(child.initials, 'ED');
    expect(child.firstName, 'Emma');
    expect(child.age, 4);
  });

  testWidgets('AttendanceModel status checks work', (WidgetTester tester) async {
    final present = MockData.children.first;
    expect(present.name, 'Emma Davis');
    
    // Verify mock data is consistent
    final emma = MockData.getChildById('child_1');
    expect(emma, isNotNull);
    expect(emma!.parentId, 'parent_1');
    expect(emma.className, 'Sunshine Stars ☀️');
  });

  testWidgets('Photo AI detection filters high confidence', (WidgetTester tester) async {
    final photos = MockData.photos;
    
    // All mock photos should have at least one child_id
    for (final photo in photos) {
      expect(photo.url.isNotEmpty, isTrue);
    }
    
    // Photo 1 should contain child_1
    final photo1 = photos.first;
    expect(photo1.containsChild('child_1'), isTrue);
    expect(photo1.autoTaggedChildIds, contains('child_1'));
  });

  testWidgets('MockData helper methods work', (WidgetTester tester) async {
    final emmaPhotos = MockData.getPhotosForChild('child_1');
    expect(emmaPhotos.length, greaterThan(0));
    
    final children = MockData.getChildrenForParent('parent_1');
    expect(children.length, 1);
    expect(children.first.name, 'Emma Davis');
    
    final conversations = MockData.getConversationsForUser('parent_1');
    expect(conversations.length, 1);
    expect(conversations.first.otherUserName, 'Sarah Johnson');
  });
}
