enum RaceStatus {
  betting, // ベット受付中
  racing, // レース中
  finished; // レース終了

  bool get isBetting => this == RaceStatus.betting;
  bool get isRacing => this == RaceStatus.racing;
  bool get isFinished => this == RaceStatus.finished;
}
