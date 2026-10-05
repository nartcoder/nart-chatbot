import 'package:hive/hive.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/models/message_role.dart';

/// Hive tip numaraları.
class HiveTypeIds {
  const HiveTypeIds._();

  static const chatMessage = 1;
  static const chatSession = 2;
}

/// ChatMessage kaydını okur ve yazar.
class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = HiveTypeIds.chatMessage;

  @override
  ChatMessage read(BinaryReader reader) {
    final version = reader.readByte();
    if (version != 1 && version != 2) {
      throw HiveError('ChatMessage sürümü desteklenmiyor: $version');
    }
    final id = reader.readString();
    final roleIndex = reader.readByte();
    final role = roleIndex >= 0 && roleIndex < MessageRole.values.length
        ? MessageRole.values[roleIndex]
        : MessageRole.ai;
    return ChatMessage(
      id: id,
      role: role,
      textContent: reader.readString(),
      imagePath: reader.read() as String?,
      filePath: reader.read() as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      fileName: reader.read() as String?,
      fileContext: reader.read() as String?,
      toolCallId: version >= 2 ? reader.read() as String? : null,
      toolName: version >= 2 ? reader.read() as String? : null,
      toolStatus: version >= 2 ? reader.read() as String? : null,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(2)
      ..writeString(obj.id)
      ..writeByte(obj.role.index)
      ..writeString(obj.textContent)
      ..write(obj.imagePath)
      ..write(obj.filePath)
      ..writeInt(obj.timestamp.millisecondsSinceEpoch)
      ..write(obj.fileName)
      ..write(obj.fileContext)
      ..write(obj.toolCallId)
      ..write(obj.toolName)
      ..write(obj.toolStatus);
  }
}

/// ChatSession kaydını okur ve yazar.
class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = HiveTypeIds.chatSession;

  @override
  ChatSession read(BinaryReader reader) {
    final version = reader.readByte();
    if (version != 1 && version != 2) {
      throw HiveError('ChatSession sürümü desteklenmiyor: $version');
    }
    final id = reader.readString();
    final title = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final rawMessages = reader.read();
    final messages = rawMessages is List
        ? rawMessages.whereType<ChatMessage>().toList()
        : <ChatMessage>[];
    return ChatSession(
      id: id,
      title: title,
      createdAt: createdAt,
      messages: messages,
      profileId: reader.read() as String?,
      titleGenerated: reader.readByte() == 1,
      agentId: version >= 2 ? reader.read() as String? : null,
      runId: version >= 2 ? reader.read() as String? : null,
      repoUrl: version >= 2 ? reader.read() as String? : null,
    );
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer
      ..writeByte(2)
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..write(obj.messages)
      ..write(obj.profileId)
      ..writeByte(obj.titleGenerated ? 1 : 0)
      ..write(obj.agentId)
      ..write(obj.runId)
      ..write(obj.repoUrl);
  }
}
