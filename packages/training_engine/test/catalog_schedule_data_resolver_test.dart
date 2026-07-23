import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const resolver = CatalogScheduleDataResolver();

  test('resolves cadence and session topology without inspecting the id', () {
    const source = SourceSchedule(
      reference: ComponentReference('arbitrary_schedule_name', 7),
      type: CycleScheduleMode.rotating,
      sessionsPerWeek: 3,
      sessions: [
        SourceSession(
          id: 'day_a',
          role: 'mainLift',
          movementIds: ['overhead_press'],
        ),
        SourceSession(id: 'day_b', role: 'mainLift', movementIds: ['deadlift']),
        SourceSession(
          id: 'day_c',
          role: 'mainLift',
          movementIds: ['bench_press'],
        ),
        SourceSession(id: 'day_d', role: 'mainLift', movementIds: ['squat']),
      ],
    );

    final schedule = resolver.resolve(source);

    expect(schedule.id, 'arbitrary_schedule_name');
    expect(schedule.mode, CycleScheduleMode.rotating);
    expect(schedule.allowedFrequencies, {3});
    expect(schedule.sessions.map((session) => session.id.value), [
      'day_a',
      'day_b',
      'day_c',
      'day_d',
    ]);
    expect(
      schedule.sessions.map((session) => session.role),
      everyElement('mainLift'),
    );
    expect(
      schedule.sessions.map(
        (session) =>
            session.movementIds.map((movement) => movement.value).toList(),
      ),
      [
        ['overhead_press'],
        ['deadlift'],
        ['bench_press'],
        ['squat'],
      ],
    );
  });

  test('preserves multi-movement session boundaries', () {
    const source = SourceSchedule(
      reference: ComponentReference('paired', 1),
      type: CycleScheduleMode.multiMovement,
      sessionsPerWeek: 2,
      sessions: [
        SourceSession(
          id: 'day_one',
          role: 'pairedLifts',
          movementIds: ['squat', 'bench_press'],
        ),
        SourceSession(
          id: 'day_two',
          role: 'pairedLifts',
          movementIds: ['deadlift', 'overhead_press'],
        ),
      ],
    );

    final schedule = resolver.resolve(source);

    expect(schedule.allowedFrequencies, {2});
    expect(
      schedule.sessions.map(
        (session) =>
            session.movementIds.map((movement) => movement.value).toList(),
      ),
      [
        ['squat', 'bench_press'],
        ['deadlift', 'overhead_press'],
      ],
    );
  });

  test('requires explicit cadence for scheduled compilation', () {
    const source = SourceSchedule(
      reference: ComponentReference('legacy', 1),
      sessions: [
        SourceSession(id: 'main', role: 'mainLift', movementIds: ['squat']),
      ],
    );

    expect(
      () => resolver.resolve(source),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('sessionsPerWeek is required'),
        ),
      ),
    );
  });

  test('rejects cadence incompatible with the declared mode', () {
    const source = SourceSchedule(
      reference: ComponentReference('invalid_fixed', 1),
      type: CycleScheduleMode.fixed,
      sessionsPerWeek: 1,
      sessions: [
        SourceSession(id: 'first', role: 'mainLift', movementIds: ['squat']),
        SourceSession(
          id: 'second',
          role: 'mainLift',
          movementIds: ['bench_press'],
        ),
      ],
    );

    expect(
      () => resolver.resolve(source),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('must equal the session count for fixed schedules'),
        ),
      ),
    );
  });
}
