import 'package:flutter_test/flutter_test.dart';
import 'package:reader_plugin/reader_plugin.dart';
import 'package:reader_plugin/reader_plugin_platform_interface.dart';
import 'package:reader_plugin/reader_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockReaderPluginPlatform
    with MockPlatformInterfaceMixin
    implements ReaderPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ReaderPluginPlatform initialPlatform = ReaderPluginPlatform.instance;

  test('$MethodChannelReaderPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelReaderPlugin>());
  });

  test('getPlatformVersion', () async {
    //ReaderPlugin readerPlugin = ReaderPlugin(); Linea comentada***
    //MockReaderPluginPlatform fakePlatform = MockReaderPluginPlatform(); Linea comentada***
    //ReaderPluginPlatform.instance = fakePlatform; Linea comentada***

    //expect(await readerPlugin.getPlatformVersion(), '42');
  });
}
