-- CONNECTION: name=VARIAN Production
WITH
  PlanTypeParameters AS (
    SELECT DISTINCT
        CASE
            WHEN Course.CourseId LIKE 'C[1-9]' THEN 'Clinical'
            WHEN Course.CourseId LIKE 'C[1-9][0-9]' THEN 'Clinical'
            ELSE 'NonClinical'
        END 'CourseType',
        Course.ClinicalStatus AS CourseStatus,
        CASE
            WHEN vv_PlanSetup.Intent IS NULL THEN 'Treatment'
            WHEN vv_PlanSetup.Intent LIKE 'VERIFICATION' THEN 'VERIFICATION'
            WHEN vv_PlanSetup.Intent IN ('RESEARCH', 'MACHINE_QA') THEN 'NonClinical'
            ELSE 'Treatment'
        END 'PlanIntent',
        CASE
            WHEN vv_PlanSetup.Status
                IN ('ExternalApproval', 'Unapproved', 'Retired', 'Reviewed', 'Rejected')
                THEN 'Reference'
            ELSE vv_PlanSetup.Status
        END 'PlanStatus',
        CASE
            WHEN DoseMatrix.DoseMatrixFile IS NULL THEN 'NoDose'
            ELSE 'HasDoseCalc'
        END 'Calculation',
        CASE
            WHEN vv_PlanSetup.StructureSetSer IS NULL THEN 'NoCT'
            ELSE 'HasCT'
        END 'PlanningCT',
        CASE
            WHEN Technique.TechniqueId IS NULL THEN ''
            ELSE Technique.TechniqueId
        END 'Field Technique',
        -- Site is the first 4 characters of the PlanSetupId and is used as a
        --   treatment site code in our centre.
        SUBSTRING(vv_PlanSetup.PlanSetupId, 1, 4) AS Site,
        vv_PlanSetup.PlanSetupSer
    FROM vv_PlanSetup
        INNER JOIN Course
          ON vv_PlanSetup.CourseSer = Course.CourseSer
        LEFT JOIN VARIAN.dbo.DoseMatrix
          ON vv_PlanSetup.PlanSetupSer = DoseMatrix.PlanSetupSer
        INNER JOIN vv_ExternalFieldCommon ON vv_PlanSetup.PlanSetupSer = vv_ExternalFieldCommon.PlanSetupSer
        INNER JOIN Technique
            ON vv_ExternalFieldCommon.TechniqueSer = Technique.TechniqueSer
    WHERE
        vv_PlanSetup.CreationDate >= '2024-01-01'
    )
SELECT DISTINCT
    vv_PlanSetup.PatientId,
    Course.CourseId,
    vv_PlanSetup.PlanSetupId,
    PlanTypeParameters.Site,
    SiteDescription.Description AS 'Site Description',
    CASE
        WHEN PlanTypeParameters.Site IN ('LUNB', 'LUNL', 'LUNR', 'MEDI', 'PLEL', 'PLER') THEN 'Lung'
        WHEN PlanTypeParameters.Site IN ('AXIL', 'AXIR', 'BREB', 'BREL', 'BRER', 'CHWB', 'CHWL',
                                         'CHWR', 'IMCB', 'SCNB', 'SCNL', 'SCNR') THEN 'Breast'
        WHEN PlanTypeParameters.Site IN ('BLAD', 'KIDL', 'KIDR', 'UREL', 'URER', 'URET') THEN 'GU'
        WHEN PlanTypeParameters.Site IN ('PROS') THEN 'Prostate'
        WHEN PlanTypeParameters.Site IN ('RECT', 'ANUS', 'COLN') THEN 'GI'
        WHEN PlanTypeParameters.Site IN ('ETHM', 'FLOO', 'GING', 'MAXB', 'MAXL', 'MAXR', 'NASA',
                                         'NASO', 'ORAL', 'OROP', 'PALH', 'PALS', 'PALX', 'PARL',
                                         'PARR', 'PITU', 'SALL', 'SALR', 'SPHE', 'SUBM', 'TONG',
                                         'TONS', 'UVUL', 'HYPO', 'LARP', 'LARY', 'PYRI', 'TRAC') THEN 'Head & Neck'
        ELSE 'Other'
    END AS 'SiteRegion',
    CASE
        WHEN Diagnosis.DiagnosisCode LIKE 'C0%' THEN 'Head & Neck'
        WHEN Diagnosis.DiagnosisCode LIKE 'C1[01234]%' THEN 'Head & Neck'
        WHEN Diagnosis.DiagnosisCode LIKE 'C19%' THEN 'GI'
        WHEN Diagnosis.DiagnosisCode LIKE 'C20%' THEN 'GI'
        WHEN Diagnosis.DiagnosisCode LIKE 'C21%' THEN 'GI'
        WHEN Diagnosis.DiagnosisCode LIKE 'C22%' THEN 'Liver'
        WHEN Diagnosis.DiagnosisCode LIKE 'C25%' THEN 'Pancreas'
        WHEN Diagnosis.DiagnosisCode LIKE 'C32%' THEN 'Head & Neck'
        WHEN Diagnosis.DiagnosisCode LIKE 'C34%' THEN 'Lung'
        WHEN Diagnosis.DiagnosisCode LIKE 'C50%' THEN 'Breast'
        WHEN Diagnosis.DiagnosisCode LIKE 'C53%' THEN 'Cervix'
        WHEN Diagnosis.DiagnosisCode LIKE 'C54%' THEN 'Uterus'
        WHEN Diagnosis.DiagnosisCode LIKE 'C56%' THEN 'Ovary'
        WHEN Diagnosis.DiagnosisCode LIKE 'C61%' THEN 'Prostate'
        WHEN Diagnosis.DiagnosisCode LIKE 'C62%' THEN 'Testis'
        WHEN Diagnosis.DiagnosisCode LIKE 'C64%' THEN 'GU'
        WHEN Diagnosis.DiagnosisCode LIKE 'C67%' THEN 'GU'
        WHEN Diagnosis.DiagnosisCode LIKE 'C68%' THEN 'GU'
        WHEN Diagnosis.DiagnosisCode LIKE 'C71%' THEN 'Brain'
        WHEN Diagnosis.DiagnosisCode LIKE 'C73%' THEN 'Thyroid'
        WHEN Diagnosis.DiagnosisCode LIKE 'C76%' THEN 'Thymus'
        WHEN Diagnosis.DiagnosisCode LIKE 'C77%' THEN 'Lymphoma'
        WHEN Diagnosis.DiagnosisCode LIKE 'C79%' THEN 'Adrenal'
        WHEN Diagnosis.DiagnosisCode LIKE 'C8[12345678]%' THEN 'Lymphoma'
        WHEN Diagnosis.DiagnosisCode LIKE 'C89%' THEN 'Myeloma'
        WHEN Diagnosis.DiagnosisCode LIKE 'C9[012345]%' THEN 'Leukaemia'
        WHEN Diagnosis.DiagnosisCode LIKE 'C96%' THEN 'Sarcoma'
        ELSE 'Other'
    END AS 'DiseaseSite',
    Diagnosis.DiagnosisTableName,
    Diagnosis.DiagnosisCode,
    Diagnosis.Description AS 'Diagnosis',
    Diagnosis.DiagnosisType,
    StructureSet.StructureSetId,
    vv_RTPlan.PrescribedDose * 100 AS DosePerFraction,
    vv_RTPlan.PrescribedDose * vv_RTPlan.NoFractions * 100 AS PrescribedDose,
    vv_RTPlan.NoFractions AS Fractions,
    CONVERT(VARCHAR, vv_RTPlan.PrescribedDose * vv_RTPlan.NoFractions * 100,0) +
        ' cGy in ' + CONVERT(VARCHAR, vv_RTPlan.NoFractions,0) +
        ' Fractions' AS Prescription,
    vv_PlanSetup.CreationDate,
    vv_PlanSetup.StatusDate,
    Course.CourseSer,
    vv_PlanSetup.PlanSetupSer
FROM vv_PlanSetup
    LEFT JOIN Course
        ON vv_PlanSetup.CourseSer = Course.CourseSer
    LEFT JOIN VARIAN.dbo.CourseDiagnosis
        ON Course.CourseSer = CourseDiagnosis.CourseSer
    LEFT Join VARIAN.dbo.Diagnosis
        ON CourseDiagnosis.DiagnosisSer = Diagnosis.DiagnosisSer
    LEFT JOIN VARIAN.dbo.DoseMatrix
        ON vv_PlanSetup.PlanSetupSer = DoseMatrix.PlanSetupSer
    INNER JOIN PlanTypeParameters
    ON vv_PlanSetup.PlanSetupSer = PlanTypeParameters.PlanSetupSer
    -- The Activity Code Modifier is a custom table used for our Ontario Health reporting.
    -- It contains a 4 character site code and a description of the site.
    LEFT JOIN ActivityCodeMd AS SiteDescription
        ON SiteDescription.Modifier = PlanTypeParameters.Site
    LEFT JOIN vv_RTPlan
        ON vv_PlanSetup.PlanSetupSer = vv_RTPlan.PlanSetupSer
    LEFT JOIN StructureSet
        ON vv_PlanSetup.StructureSetSer= StructureSet.StructureSetSer
    LEFT JOIN vv_ExternalFieldCommon ON vv_PlanSetup.PlanSetupSer = vv_ExternalFieldCommon.PlanSetupSer
    LEFT JOIN Radiation ON vv_ExternalFieldCommon.RadiationSer = Radiation.RadiationSer
    LEFT JOIN MLCPlan ON Radiation.RadiationSer = MLCPlan.RadiationSer
WHERE
    PlanTypeParameters.CourseType = 'Clinical'
    AND PlanTypeParameters.PlanIntent = 'Treatment'
    AND (
        (PlanTypeParameters.CourseStatus = 'ACTIVE'
            AND PlanTypeParameters.PlanStatus = 'Completed')
        OR (PlanTypeParameters.CourseStatus = 'COMPLETED'
            AND PlanTypeParameters.PlanStatus IN ('PlanApproval', 'TreatApproval', 'Completed'))
        )

ORDER BY
    vv_PlanSetup.StatusDate DESC,
    PlanTypeParameters.Site,
    PatientId,
    CourseId,
    PlanSetupId
