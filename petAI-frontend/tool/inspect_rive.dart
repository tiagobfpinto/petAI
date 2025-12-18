import 'dart:io';

import 'package:rive/rive.dart' as rive;

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args.first : 'assets/rive/pet_home.riv';
  final fileOnDisk = File(path);
  if (!fileOnDisk.existsSync()) {
    stderr.writeln('Rive file not found: $path');
    exitCode = 2;
    return;
  }

  final file = await rive.File.path(path, riveFactory: rive.Factory.rive);
  if (file == null) {
    stderr.writeln('Failed to decode Rive file: $path');
    exitCode = 3;
    return;
  }

  try {
    stdout.writeln('Loaded: $path');
    stdout.writeln('ViewModels: ${file.viewModelCount}');
    for (var i = 0; i < file.viewModelCount; i++) {
      final vm = file.viewModelByIndex(i);
      if (vm == null) continue;
      stdout.writeln('  VM[$i]: ${vm.name}');
      stdout.writeln('    properties: ${vm.properties.map((p) => '${p.name}:${p.type}').join(', ')}');
      stdout.writeln('    instances: ${vm.instanceCount}');
    }

    for (var a = 0; ; a++) {
      final artboard = file.artboardAt(a);
      if (artboard == null) break;
      stdout.writeln('Artboard[$a]: ${artboard.name}');
      final smCount = artboard.stateMachineCount();
      stdout.writeln('  stateMachines: $smCount');
      for (var s = 0; s < smCount; s++) {
        final sm = artboard.stateMachineAt(s);
        if (sm == null) continue;
        stdout.writeln('    SM[$s]: ${sm.name}');
        final triggers = <String>[];
        final booleans = <String>[];
        final numbers = <String>[];

        // ignore: deprecated_member_use
        for (final input in sm.inputs) {
          if (input is rive.TriggerInput) {
            triggers.add(input.name);
          } else if (input is rive.BooleanInput) {
            booleans.add(input.name);
          } else if (input is rive.NumberInput) {
            numbers.add(input.name);
          }
        }
        stdout.writeln('      triggers: ${triggers.join(', ')}');
        stdout.writeln('      booleans: ${booleans.join(', ')}');
        stdout.writeln('      numbers: ${numbers.join(', ')}');
      }
    }
  } finally {
    file.dispose();
  }
}
