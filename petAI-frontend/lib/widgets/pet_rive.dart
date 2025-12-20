import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

class PetRive extends StatefulWidget {
  const PetRive({
    super.key,
    this.assetPath = "assets/rive/pet_home.riv",
    this.triggers = const [],
    this.fit = rive.Fit.cover,
    this.fallback,
  });

  final String assetPath;
  final List<String> triggers;
  final rive.Fit fit;
  final Widget? fallback;

  @override
  State<PetRive> createState() => _PetRiveState();
}

class _PetRiveState extends State<PetRive> {
  late rive.FileLoader _fileLoader;
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _viewModel;
  rive.RiveWidgetController? _viewModelController;
  String _appliedSignature = "";

  @override
  void initState() {
    super.initState();
    _fileLoader = rive.FileLoader.fromAsset(
      widget.assetPath,
      riveFactory: rive.Factory.rive,
    );
  }

  @override
  void didUpdateWidget(covariant PetRive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _fileLoader.dispose();
      _fileLoader = rive.FileLoader.fromAsset(
        widget.assetPath,
        riveFactory: rive.Factory.rive,
      );
      _controller = null;
      _viewModel = null;
      _viewModelController = null;
      _appliedSignature = "";
      return;
    }

    if (_signatureForTriggers(oldWidget.triggers) != _signatureForTriggers(widget.triggers)) {
      _appliedSignature = "";
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyTriggersIfReady());
    }
  }

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  static String _normalizeRiveName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]"), "");
  }

  static List<String> _triggerNameCandidates(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>[trimmed];

    final hatAbbrev = RegExp(r"^h[_-]?(\d+)$", caseSensitive: false).firstMatch(trimmed);
    if (hatAbbrev != null) {
      candidates.add("hat_${hatAbbrev.group(1)}");
    }

    final hatFull = RegExp(r"^hat[_-]?(\d+)$", caseSensitive: false).firstMatch(trimmed);
    if (hatFull != null) {
      final id = hatFull.group(1);
      if (id != null) {
        candidates.add("hat_$id");
        candidates.add("h_$id");
      }
    }

    final unique = <String>[];
    for (final candidate in candidates) {
      if (unique.contains(candidate)) continue;
      unique.add(candidate);
    }
    return unique;
  }

  static String _describeRiveInputs(rive.StateMachine stateMachine) {
    final triggers = <String>[];
    final booleans = <String>[];
    final numbers = <String>[];

    // ignore: deprecated_member_use
    for (final input in stateMachine.inputs) {
      if (input is rive.TriggerInput) {
        triggers.add(input.name);
      } else if (input is rive.BooleanInput) {
        booleans.add(input.name);
      } else if (input is rive.NumberInput) {
        numbers.add(input.name);
      }
    }

    final parts = <String>[];
    if (triggers.isNotEmpty) parts.add("triggers=[${triggers.join(", ")}]");
    if (booleans.isNotEmpty) parts.add("booleans=[${booleans.join(", ")}]");
    if (numbers.isNotEmpty) parts.add("numbers=[${numbers.join(", ")}]");
    return parts.isEmpty ? "inputs=[]" : parts.join(" ");
  }

  void _maybeBindViewModel(rive.RiveWidgetController controller) {
    if (_viewModelController == controller) return;
    _viewModelController = controller;
    _viewModel = null;

    try {
      _viewModel = controller.dataBind(const rive.AutoBind());
      if (kDebugMode) {
        debugPrint(
          "[pet_rive] bound view model: ${_viewModel?.name} (sm=${controller.stateMachine.name})",
        );
      }
    } catch (err) {
      if (kDebugMode) {
        debugPrint("[pet_rive] no view model binding (sm=${controller.stateMachine.name}): $err");
      }
    }
  }

  String _signatureForTriggers(List<String> triggers) {
    final effective = <String>[];
    for (final trigger in triggers) {
      final trimmed = trigger.trim();
      if (trimmed.isEmpty) continue;
      if (effective.contains(trimmed)) continue;
      effective.add(trimmed);
    }
    return effective.join("|");
  }

  void _applyTriggersIfReady() {
    final controller = _controller;
    if (controller == null) return;

    final signature = _signatureForTriggers(widget.triggers);
    if (signature.isEmpty || signature == _appliedSignature) return;

    for (final trigger in widget.triggers) {
      _fireTrigger(controller, trigger);
    }
    _appliedSignature = signature;
  }

  void _fireTrigger(rive.RiveWidgetController controller, String triggerName) {
    final originalName = triggerName.trim();
    if (originalName.isEmpty) return;

    final stateMachine = controller.stateMachine;

    bool tryFire(String name) {
      // 1) Try state machine trigger input (legacy inputs).
      // ignore: deprecated_member_use
      final direct = stateMachine.trigger(name);
      if (direct != null) {
        direct.fire();
        return true;
      }

      // 2) Try normalized match across inputs (handles case/underscore differences).
      final normalized = _normalizeRiveName(name);
      rive.Input? matched;
      // ignore: deprecated_member_use
      for (final input in stateMachine.inputs) {
        if (_normalizeRiveName(input.name) == normalized) {
          matched = input;
          break;
        }
      }

      if (matched is rive.TriggerInput) {
        matched.fire();
        return true;
      }

      // Some files use booleans/numbers as pseudo-triggers. Pulse them.
      if (matched is rive.BooleanInput) {
        final input = matched;
        input.value = true;
        Future.delayed(const Duration(milliseconds: 60), () {
          if (_controller == controller) {
            input.value = false;
          }
        });
        return true;
      }

      if (matched is rive.NumberInput) {
        final input = matched;
        input.value = 1;
        Future.delayed(const Duration(milliseconds: 60), () {
          if (_controller == controller) {
            input.value = 0;
          }
        });
        return true;
      }

      // 3) Try data-binding triggers (new Rive workflow).
      _maybeBindViewModel(controller);
      final viewModel = stateMachine.boundRuntimeViewModelInstance ?? _viewModel;
      if (viewModel != null) {
        final vmTrigger = viewModel.trigger(name);
        if (vmTrigger != null) {
          vmTrigger.trigger();
          return true;
        }

        final normalizedVm = _normalizeRiveName(name);
        for (final property in viewModel.properties) {
          if (property.type != rive.DataType.trigger) continue;
          if (_normalizeRiveName(property.name) == normalizedVm) {
            viewModel.trigger(property.name)?.trigger();
            return true;
          }
        }
      }

      return false;
    }

    for (final candidate in _triggerNameCandidates(originalName)) {
      if (tryFire(candidate)) return;
    }

    if (kDebugMode) {
      debugPrint(
        "[pet_rive] Unknown input \"$originalName\" on state machine \"${stateMachine.name}\" (${_describeRiveInputs(stateMachine)})",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ?? const SizedBox.expand();
    return rive.RiveWidgetBuilder(
      fileLoader: _fileLoader,
      stateMachineSelector: const rive.StateMachineDefault(),
      builder: (context, state) => switch (state) {
        rive.RiveLoading() => Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
        rive.RiveFailed() => fallback,
        rive.RiveLoaded() => Builder(
            builder: (context) {
              final controller = state.controller;
              if (_controller != controller) {
                _controller = controller;
                _viewModel = null;
                _viewModelController = null;
                _appliedSignature = "";
              }
              WidgetsBinding.instance.addPostFrameCallback((_) => _applyTriggersIfReady());
              return rive.RiveWidget(
                controller: controller,
                fit: widget.fit,
              );
            },
          ),
      },
    );
  }
}

