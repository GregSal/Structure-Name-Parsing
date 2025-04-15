-- CONNECTION: name=VARIAN Production
SELECT
  VolumeType AS VolumeType,
  Description AS VolumeTypeDescription,
  DicomType AS DicomType
FROM
  VARIAN.dbo.VolumeType
WHERE
  ObjectStatus='Active'
