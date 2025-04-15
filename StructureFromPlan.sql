SELECT DISTINCT
    Structure.ROINumber AS ROINumber,
    Structure.StructureId AS StructureID,
    VolumeType.VolumeType AS VolumeType,
    VolumeType.DicomType AS DicomType,
    Structure.Status AS Status,
    Structure.StatusDate AS Approval_Date,
    Structure.GenerationAlgorithm AS GenerationMethod,
    PlanSetup.PlanSetupSer AS PlanSetupSer
FROM Patient
LEFT JOIN Course
    ON Patient.PatientSer = Course.PatientSer
LEFT JOIN PlanSetup
    ON Course.CourseSer = PlanSetup.CourseSer
LEFT JOIN StructureSet
    ON PlanSetup.StructureSetSer = StructureSet.StructureSetSer
LEFT JOIN Structure
    ON StructureSet.StructureSetSer = Structure.StructureSetSer
LEFT JOIN Material
    ON Structure.MaterialSer = Material.MaterialSer
LEFT JOIN PatientVolume
    ON Structure.PatientVolumeSer = PatientVolume.PatientVolumeSer
LEFT JOIN VolumeType
    ON PatientVolume.VolumeTypeSer = VolumeType.VolumeTypeSer
LEFT JOIN StructureType
    ON Structure.StructureTypeSer = StructureType.StructureTypeSer
WHERE
    PlanSetup.PlanSetupSer LIKE '{Plan_Ser}'
ORDER BY
    VolumeType.VolumeType ASC,
    Structure.StructureId ASC
