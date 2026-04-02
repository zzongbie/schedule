import 'package:flutter/material.dart';

class DialogField {
  final TextEditingController controller;
  final String labelText;
  final bool readOnly;
  final TextInputType keyboardType;

  final bool isDropdown;
  final bool isRadio;
  final List<String> dropdownItems;
  final List<String> dropdownValues;

  DialogField({
    required this.controller,
    required this.labelText,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.isDropdown = false,
    this.isRadio = false,
    this.dropdownItems = const [],
    this.dropdownValues = const [],
  });
}

class CommonDialog {
  /// 단순 확인/취소 다이얼로그
  static void showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmText = '확인',
    String cancelText = '취소',
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(cancelText, style: const TextStyle(color: Colors.black54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// 폼(입력 필드) 형태의 다이얼로그 (등록/수정용)
  static void showFormDialog({
    required BuildContext context,
    required String title,
    required List<DialogField> fields,
    required VoidCallback onSave,
    String saveText = '저장',
    String cancelText = '취소',
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields.map((field) {
                if (field.isDropdown) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return DropdownButtonFormField<String>(
                        value: field.controller.text.isEmpty && field.dropdownValues.isNotEmpty
                            ? null
                            : field.controller.text,
                        decoration: InputDecoration(labelText: field.labelText),
                        items: List.generate(field.dropdownItems.length, (index) {
                          return DropdownMenuItem<String>(
                            value: field.dropdownValues.isNotEmpty ? field.dropdownValues[index] : field.dropdownItems[index],
                            child: Text(field.dropdownItems[index]),
                          );
                        }),
                        onChanged: field.readOnly ? null : (value) {
                          if (value != null) {
                            setState(() {
                              field.controller.text = value;
                            });
                          }
                        },
                      );
                    }
                  );
                } else if (field.isRadio) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                            child: Text(field.labelText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                          ),
                          Row(
                            children: List.generate(field.dropdownItems.length, (index) {
                              final val = field.dropdownValues.isNotEmpty ? field.dropdownValues[index] : field.dropdownItems[index];
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Radio<String>(
                                    value: val,
                                    groupValue: field.controller.text,
                                    onChanged: field.readOnly ? null : (value) {
                                      if (value != null) {
                                        setState(() {
                                          field.controller.text = value;
                                        });
                                      }
                                    },
                                  ),
                                  Text(field.dropdownItems[index]),
                                  const SizedBox(width: 16),
                                ],
                              );
                            }),
                          ),
                        ],
                      );
                    }
                  );
                }
                return TextField(
                  controller: field.controller,
                  readOnly: field.readOnly,
                  keyboardType: field.keyboardType,
                  decoration: InputDecoration(labelText: field.labelText),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(cancelText, style: const TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onSave();
              },
              child: Text(saveText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
