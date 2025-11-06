import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../utils/http_service.dart' as http;
import 'dialog.dart';

// 注册对话框
Future<bool?> registerDialog() async {
  var username = TextEditingController();
  var email = TextEditingController();
  var password = TextEditingController();
  var confirmPassword = TextEditingController();
  final userFocusNode = FocusNode()..requestFocus();
  Timer(Duration(milliseconds: 100), () => userFocusNode..requestFocus());

  String? usernameMsg;
  String? emailMsg;
  String? passwordMsg;
  String? confirmPasswordMsg;
  var isInProgress = false;

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    username.addListener(() {
      if (usernameMsg != null) {
        setState(() => usernameMsg = null);
      }
    });

    email.addListener(() {
      if (emailMsg != null) {
        setState(() => emailMsg = null);
      }
    });

    password.addListener(() {
      if (passwordMsg != null) {
        setState(() => passwordMsg = null);
      }
    });

    confirmPassword.addListener(() {
      if (confirmPasswordMsg != null) {
        setState(() => confirmPasswordMsg = null);
      }
    });

    onDialogCancel() {
      isInProgress = false;
      close(false);
    }

    onRegister() async {
      // 验证输入（根据API文档：用户名至少3位，密码8-20位）
      final usernameText = username.text.trim();
      if (usernameText.isEmpty) {
        setState(() => usernameMsg = translate('Username missed'));
        return;
      }
      if (usernameText.length < 3) {
        setState(() => usernameMsg = translate('Username must be at least 3 characters'));
        return;
      }
      
      // 邮箱为可选字段，如果有填写则验证格式
      if (email.text.isNotEmpty && !email.text.contains('@')) {
        setState(() => emailMsg = translate('Invalid email format'));
        return;
      }
      
      if (password.text.isEmpty) {
        setState(() => passwordMsg = translate('Password missed'));
        return;
      }
      if (password.text.length < 8 || password.text.length > 20) {
        setState(() => passwordMsg = translate('Password must be 8-20 characters'));
        return;
      }
      if (confirmPassword.text.isEmpty) {
        setState(() => confirmPasswordMsg = translate('Please confirm password'));
        return;
      }
      if (password.text != confirmPassword.text) {
        setState(() => confirmPasswordMsg = translate('Passwords do not match'));
        return;
      }

      setState(() => isInProgress = true);
      
      try {
        final url = await bind.mainGetApiServer();
        if (url.trim().isEmpty) {
          setState(() {
            emailMsg = translate('API server not configured');
            isInProgress = false;
          });
          return;
        }

        // 构建注册请求体（根据API文档，只需要username和password）
        final body = {
          'username': username.text.trim(),
          'password': password.text,
        };

        final resp = await http.post(
          Uri.parse('$url/api/register'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));

        // 先检查响应状态码和内容
        if (resp.statusCode != 200) {
          String errorMsg = translate('Registration failed');
          // 检查是否为404错误（端点不存在）
          if (resp.statusCode == 404) {
            errorMsg = translate('Registration endpoint not found. Please check API server configuration.');
          } else {
            try {
              final responseText = decode_http_response(resp);
              // 检查是否为HTML响应（通常是404页面）
              if (responseText.trim().startsWith('<!DOCTYPE') || responseText.trim().startsWith('<html')) {
                errorMsg = translate('Registration endpoint not found. Server returned HTML page.');
              } else {
                final errorBody = jsonDecode(responseText);
                if (errorBody is Map && errorBody['error'] != null) {
                  errorMsg = errorBody['error'].toString();
                } else {
                  errorMsg = 'HTTP ${resp.statusCode}';
                }
              }
            } catch (e) {
              debugPrint("register: Failed to parse error response: $e");
              errorMsg = 'HTTP ${resp.statusCode}';
            }
          }
          setState(() {
            emailMsg = errorMsg;
            isInProgress = false;
          });
          return;
        }

        // 解析成功响应
        final Map<String, dynamic> responseBody;
        try {
          final responseText = decode_http_response(resp);
          if (responseText.isEmpty) {
            setState(() {
              emailMsg = translate('Server returned empty response');
              isInProgress = false;
            });
            return;
          }
          responseBody = jsonDecode(responseText);
        } catch (e) {
          debugPrint("register: jsonDecode resp body failed: ${e.toString()}");
          setState(() {
            // 尝试显示原始错误信息
            try {
              final responseText = decode_http_response(resp);
              if (responseText.trim().startsWith('<!DOCTYPE') || responseText.trim().startsWith('<html')) {
                emailMsg = translate('Registration endpoint not found. Server returned HTML page.');
              } else if (responseText.contains('error') || responseText.contains('Error')) {
                emailMsg = responseText.length > 100 ? responseText.substring(0, 100) : responseText;
              } else {
                emailMsg = translate('Server response error: Invalid JSON format');
              }
            } catch (_) {
              emailMsg = translate('Server response error');
            }
            isInProgress = false;
          });
          return;
        }

        // 检查响应中的错误字段（根据API文档，成功时code=1）
        if (responseBody['error'] != null) {
          setState(() {
            emailMsg = responseBody['error'].toString();
            isInProgress = false;
          });
        } else if (responseBody['code'] == 1) {
          // 注册成功（code=1）
          final message = responseBody['message']?.toString() ?? translate('Registration successful');
          showToast(message);
          // 注册成功后可以选择自动打开登录对话框
          close(true);
          // 可选：自动打开登录对话框
          // await Future.delayed(const Duration(milliseconds: 500));
          // await loginDialog();
        } else if (responseBody['code'] != null && responseBody['code'] != 1) {
          // 注册失败（code不等于1）
          setState(() {
            emailMsg = responseBody['message']?.toString() ?? responseBody['error']?.toString() ?? translate('Registration failed');
            isInProgress = false;
          });
        } else {
          // 兼容处理：没有code字段但也没有error字段，可能是其他格式的成功响应
          if (responseBody['user'] != null || responseBody.containsKey('username')) {
            showToast(translate('Registration successful'));
            close(true);
          } else {
            setState(() {
              emailMsg = translate('Registration failed: Unknown response format');
              isInProgress = false;
            });
          }
        }
      } catch (e) {
        debugPrint('Registration error: $e');
        setState(() {
          emailMsg = translate('Registration failed: $e');
          isInProgress = false;
        });
      }
    }

    final title = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate('Register'),
        ).marginOnly(top: MyTheme.dialogPadding),
        InkWell(
          child: Icon(
            Icons.close,
            size: 25,
            color: Theme.of(context)
                .textTheme
                .titleLarge
                ?.color
                ?.withOpacity(0.55),
          ),
          onTap: onDialogCancel,
          hoverColor: Colors.red,
          borderRadius: BorderRadius.circular(5),
        ).marginOnly(top: 10, right: 15),
      ],
    );
    final titlePadding = EdgeInsets.fromLTRB(MyTheme.dialogPadding, 0, 0, 0);

    return CustomAlertDialog(
      title: title,
      titlePadding: titlePadding,
      contentBoxConstraints: BoxConstraints(minWidth: 400),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8.0),
          DialogTextField(
            title: translate(DialogTextField.kUsernameTitle),
            controller: username,
            focusNode: userFocusNode,
            prefixIcon: DialogTextField.kUsernameIcon,
            errorText: usernameMsg,
          ),
          DialogTextField(
            title: '${translate('Email')} (${translate('Optional')})',
            controller: email,
            prefixIcon: Icon(Icons.email),
            errorText: emailMsg,
            keyboardType: TextInputType.emailAddress,
            hintText: translate('Optional'),
          ),
          PasswordWidget(
            controller: password,
            autoFocus: false,
            reRequestFocus: false,
            errorText: passwordMsg,
          ),
          PasswordWidget(
            controller: confirmPassword,
            autoFocus: false,
            reRequestFocus: false,
            errorText: confirmPasswordMsg,
            title: translate('Confirm Password'),
          ),
          if (isInProgress) const LinearProgressIndicator(),
          const SizedBox(height: 12.0),
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 38,
                  width: 200,
                  child: ElevatedButton(
                    onPressed: isInProgress ? null : onRegister,
                    child: Text(
                      translate('Register'),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      onCancel: onDialogCancel,
      onSubmit: onRegister,
    );
  });

  return res;
}

