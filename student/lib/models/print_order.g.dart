// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SelectedFileAdapter extends TypeAdapter<SelectedFile> {
  @override
  final int typeId = 0;

  @override
  SelectedFile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SelectedFile(
      name: fields[0] as String,
      path: fields[1] as String,
      sizeBytes: fields[2] as int,
      pageCount: fields[3] as int,
      bytes: fields[4] as Uint8List?,
    );
  }

  @override
  void write(BinaryWriter writer, SelectedFile obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.sizeBytes)
      ..writeByte(3)
      ..write(obj.pageCount)
      ..writeByte(4)
      ..write(obj.bytes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedFileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrintConfigAdapter extends TypeAdapter<PrintConfig> {
  @override
  final int typeId = 1;

  @override
  PrintConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrintConfig(
      paperSize: fields[0] as String,
      printType: fields[1] as String,
      printSide: fields[2] as String,
      copies: fields[3] as int,
      bindingType: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PrintConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.paperSize)
      ..writeByte(1)
      ..write(obj.printType)
      ..writeByte(2)
      ..write(obj.printSide)
      ..writeByte(3)
      ..write(obj.copies)
      ..writeByte(4)
      ..write(obj.bindingType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentDetailsAdapter extends TypeAdapter<StudentDetails> {
  @override
  final int typeId = 2;

  @override
  StudentDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentDetails(
      name: fields[0] as String,
      studentId: fields[1] as String,
      phone: fields[2] as String,
      email: fields[3] as String,
      additionalInfo: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StudentDetails obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.additionalInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentVerificationAdapter extends TypeAdapter<PaymentVerification> {
  @override
  final int typeId = 3;

  @override
  PaymentVerification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentVerification(
      isVerified: fields[0] as bool,
      transactionId: fields[1] as String?,
      amount: fields[2] as double?,
      confidenceScore: fields[3] as double,
      rawText: fields[4] as String?,
      screenshotPath: fields[5] as String?,
      screenshotBytes: fields[6] as Uint8List?,
      failureMessage: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentVerification obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.isVerified)
      ..writeByte(1)
      ..write(obj.transactionId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.confidenceScore)
      ..writeByte(4)
      ..write(obj.rawText)
      ..writeByte(5)
      ..write(obj.screenshotPath)
      ..writeByte(6)
      ..write(obj.screenshotBytes)
      ..writeByte(7)
      ..write(obj.failureMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentVerificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrintOrderAdapter extends TypeAdapter<PrintOrder> {
  @override
  final int typeId = 4;

  @override
  PrintOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrintOrder(
      orderId: fields[0] as String,
      files: (fields[1] as List).cast<SelectedFile>(),
      config: fields[2] as PrintConfig,
      student: fields[3] as StudentDetails,
      payment: fields[4] as PaymentVerification?,
      createdAt: fields[5] as DateTime,
      status: fields[6] as String,
      retryCount: fields[7] as int,
      errorMessage: fields[8] as String?,
      mergedPdfBytes: fields[9] as Uint8List?,
      frontPagePath: fields[10] as String?,
      lastRetryAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PrintOrder obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.orderId)
      ..writeByte(1)
      ..write(obj.files)
      ..writeByte(2)
      ..write(obj.config)
      ..writeByte(3)
      ..write(obj.student)
      ..writeByte(4)
      ..write(obj.payment)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.retryCount)
      ..writeByte(8)
      ..write(obj.errorMessage)
      ..writeByte(9)
      ..write(obj.mergedPdfBytes)
      ..writeByte(10)
      ..write(obj.frontPagePath)
      ..writeByte(11)
      ..write(obj.lastRetryAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
