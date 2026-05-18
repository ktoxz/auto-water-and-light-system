import 'package:flutter/material.dart';
import '../responsive_utils.dart';

class DeviceToggle extends StatefulWidget {
  final String label;
  final bool initialValue;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const DeviceToggle({
    super.key,
    required this.label,
    required this.initialValue,
    required this.icon,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<DeviceToggle> createState() => _DeviceToggleState();
}

class _DeviceToggleState extends State<DeviceToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void didUpdateWidget(DeviceToggle old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue) {
      _value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;

    return Card(
      child: ListTile(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, type: 'sm')),
          decoration: BoxDecoration(
            color: _value
                ? activeColor.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.icon,
            color: _value ? activeColor : Colors.grey,
          ),
        ),
        title: Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _value ? 'Đang BẬT' : 'Đang TẮT',
          style: TextStyle(
            color: _value ? activeColor : Colors.grey,
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: _value,
          onChanged: widget.enabled
              ? (val) {
                  setState(() => _value = val);
                  widget.onChanged(val);
                }
              : null,
          activeColor: activeColor,
        ),
      ),
    );
  }
}
