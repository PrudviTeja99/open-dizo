import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/watch_alarm.dart';
import '../../../models/watch_settings.dart';
import '../../../services/ble_service.dart';

/// Alarms & Reminders Manager: Watch Alarms, Sedentary Alerts, and Drink Water Reminders
class RemindersTab extends StatefulWidget {
  final BleService bleService;

  const RemindersTab({super.key, required this.bleService});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  @override
  Widget build(BuildContext context) {
    final alarms = widget.bleService.alarms;
    final settings = widget.bleService.settings;
    final is24Hour = settings.is24HourFormat;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Alarms Section
        _buildSectionHeader(
          title: 'Watch Alarms',
          subtitle: '${alarms.length} of 8 configured',
          action: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Alarm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            onPressed: alarms.length >= 8 ? null : () => _showAddOrEditAlarmDialog(),
          ),
        ),
        const SizedBox(height: 12),

        if (alarms.isEmpty)
          _buildEmptyAlarmsCard()
        else
          ...alarms.map((alarm) => _buildAlarmCard(alarm, is24Hour)),

        const SizedBox(height: 24),

        // 2. Sedentary Inactivity Reminder Section
        _buildSectionHeader(
          title: 'Sedentary Inactivity Alert',
          subtitle: 'Vibrates when inactive for prolonged periods',
        ),
        const SizedBox(height: 12),
        _buildSedentaryCard(settings),

        const SizedBox(height: 24),

        // 3. Drink Water Reminder Section
        _buildSectionHeader(
          title: 'Hydration Reminder',
          subtitle: 'Scheduled water intake alerts throughout the day',
        ),
        const SizedBox(height: 12),
        _buildDrinkWaterCard(settings),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildEmptyAlarmsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm_off_rounded, color: AppTheme.textMuted, size: 26),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Alarms Set on Watch',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set morning wakeups and reminders to vibrate directly on your wrist.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmCard(WatchAlarm alarm, bool is24Hour) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alarm.isEnabled ? AppTheme.accent.withOpacity(0.3) : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showAddOrEditAlarmDialog(alarm: alarm),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: alarm.isEnabled ? AppTheme.accent.withOpacity(0.12) : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.alarm_rounded,
                    color: alarm.isEnabled ? AppTheme.accent : AppTheme.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.formatTime(is24Hour: is24Hour),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: alarm.isEnabled ? AppTheme.textPrimary : AppTheme.textMuted,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alarm.label.isNotEmpty
                          ? '${alarm.label} · ${alarm.repeatSummary}'
                          : alarm.repeatSummary,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Switch(
                value: alarm.isEnabled,
                onChanged: (val) => widget.bleService.toggleAlarm(alarm.id, val),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 20),
                onPressed: () => _confirmDeleteAlarm(alarm.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSedentaryCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: settings.sedentaryEnabled ? AppTheme.calories.withOpacity(0.15) : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.airline_seat_recline_normal_rounded,
                      color: settings.sedentaryEnabled ? AppTheme.calories : AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sedentary Reminder',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Alert when sitting too long',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: settings.sedentaryEnabled,
                onChanged: (val) {
                  widget.bleService.updateSedentaryReminder(
                    enabled: val,
                    intervalMinutes: settings.sedentaryIntervalMinutes,
                    startHour: settings.sedentaryStartHour,
                    endHour: settings.sedentaryEndHour,
                    dndLunch: settings.sedentaryDndEnabled,
                  );
                },
              ),
            ],
          ),
          if (settings.sedentaryEnabled) ...[
            const Divider(height: 24, color: AppTheme.borderSubtle),
            // Interval Selector chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reminder Interval', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Row(
                  children: [30, 45, 60, 90].map((mins) {
                    final isSel = settings.sedentaryIntervalMinutes == mins;
                    return GestureDetector(
                      onTap: () {
                        widget.bleService.updateSedentaryReminder(
                          enabled: true,
                          intervalMinutes: mins,
                          startHour: settings.sedentaryStartHour,
                          endHour: settings.sedentaryEndHour,
                          dndLunch: settings.sedentaryDndEnabled,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.calories : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSel ? const Color(0xFF0A0C10) : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Lunch DND toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lunch Break DND', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    Text('No alerts 12:00 PM – 02:00 PM', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                Switch(
                  value: settings.sedentaryDndEnabled,
                  onChanged: (val) {
                    widget.bleService.updateSedentaryReminder(
                      enabled: true,
                      intervalMinutes: settings.sedentaryIntervalMinutes,
                      startHour: settings.sedentaryStartHour,
                      endHour: settings.sedentaryEndHour,
                      dndLunch: val,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrinkWaterCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: settings.drinkWaterEnabled ? AppTheme.spo2.withOpacity(0.15) : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.water_drop_rounded,
                      color: settings.drinkWaterEnabled ? AppTheme.spo2 : AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Drink Water Alerts',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Stay hydrated throughout the day',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: settings.drinkWaterEnabled,
                onChanged: (val) {
                  widget.bleService.updateDrinkWaterReminder(
                    enabled: val,
                    intervalMinutes: settings.drinkWaterIntervalMinutes,
                    startHour: settings.drinkWaterStartHour,
                    endHour: settings.drinkWaterEndHour,
                  );
                },
              ),
            ],
          ),
          if (settings.drinkWaterEnabled) ...[
            const Divider(height: 24, color: AppTheme.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reminder Interval', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Row(
                  children: [30, 60, 90, 120].map((mins) {
                    final isSel = settings.drinkWaterIntervalMinutes == mins;
                    return GestureDetector(
                      onTap: () {
                        widget.bleService.updateDrinkWaterReminder(
                          enabled: true,
                          intervalMinutes: mins,
                          startHour: settings.drinkWaterStartHour,
                          endHour: settings.drinkWaterEndHour,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.spo2 : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSel ? const Color(0xFF0A0C10) : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddOrEditAlarmDialog({WatchAlarm? alarm}) async {
    int hour = alarm?.hour ?? 8;
    int minute = alarm?.minute ?? 0;
    final repeatDays = Set<int>.from(alarm?.repeatDays ?? {1, 2, 3, 4, 5});
    final labelCtrl = TextEditingController(text: alarm?.label ?? '');
    final isNew = alarm == null;

    final id = alarm?.id ?? _getNextAlarmId();

    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isNew ? 'New Watch Alarm' : 'Edit Alarm',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Time Selector (Tap to open TimePicker)
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (picked != null) {
                        setModalState(() {
                          hour = picked.hour;
                          minute = picked.minute;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            'Tap to change time',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Repeat Day Chips
                  const Text('Repeat Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final isSelected = repeatDays.contains(i);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              repeatDays.remove(i);
                            } else {
                              repeatDays.add(i);
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.accent : AppTheme.borderSubtle,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              dayLabels[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  // Label Input
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Alarm label (e.g. Wake up, Gym)',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final newAlarm = WatchAlarm(
                          id: id,
                          hour: hour,
                          minute: minute,
                          repeatDays: repeatDays,
                          isEnabled: true,
                          label: labelCtrl.text.trim(),
                        );
                        widget.bleService.addOrUpdateAlarm(newAlarm);
                        Navigator.pop(ctx);
                      },
                      child: Text(isNew ? 'Create Alarm' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _getNextAlarmId() {
    final existingIds = widget.bleService.alarms.map((a) => a.id).toSet();
    for (int i = 0; i < 8; i++) {
      if (!existingIds.contains(i)) return i;
    }
    return 0;
  }

  Future<void> _confirmDeleteAlarm(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Alarm?'),
        content: const Text('This alarm will be removed from your watch.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.heartRate),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.bleService.deleteAlarm(id);
    }
  }
}
