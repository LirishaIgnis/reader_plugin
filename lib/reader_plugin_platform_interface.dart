import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'reader_plugin_method_channel.dart';

abstract class ReaderPluginPlatform extends PlatformInterface {
  /// Constructs a ReaderPluginPlatform.
  ReaderPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static ReaderPluginPlatform _instance = MethodChannelReaderPlugin();

  /// The default instance of [ReaderPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelReaderPlugin].
  static ReaderPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ReaderPluginPlatform] when
  /// they register themselves.
  static set instance(ReaderPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
