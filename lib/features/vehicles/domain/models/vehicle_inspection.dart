class VehicleInspection {
  final bool bodyworkOkay;
  final bool tiresOkay;
  final bool lightsOkay;
  final bool wipersOkay;
  final bool glassAndMirrorsOkay;
  final bool leakFree;
  final bool equipmentComplete;
  final String notes;

  const VehicleInspection({
    required this.bodyworkOkay,
    required this.tiresOkay,
    required this.lightsOkay,
    this.wipersOkay = true,
    required this.glassAndMirrorsOkay,
    required this.leakFree,
    required this.equipmentComplete,
    required this.notes,
  });

  bool get hasIssue =>
      !bodyworkOkay ||
      !tiresOkay ||
      !lightsOkay ||
      !wipersOkay ||
      !glassAndMirrorsOkay ||
      !leakFree ||
      !equipmentComplete;
}
