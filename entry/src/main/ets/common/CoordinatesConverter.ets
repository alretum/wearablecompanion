/**
 * CoordinatesConverter - Utility for converting GPS coordinates
 * Converts decimal degrees to DMS (Degrees, Minutes, Seconds) format
 */

export enum CoordinateType {
  LATITUDE = 'LATITUDE',
  LONGITUDE = 'LONGITUDE'
}

/**
 * Converts decimal degrees to DMS (Degrees, Minutes, Seconds) format
 * @param value - The coordinate value in decimal degrees
 * @param type - The coordinate type (LATITUDE or LONGITUDE)
 * @returns Formatted string in DMS format (e.g., "51°10'44.04"N")
 */
export function toDMS(value: number, type: CoordinateType): string {
  const absValue = Math.abs(value);
  const degrees = Math.floor(absValue);
  const minutesDecimal = (absValue - degrees) * 60;
  const minutes = Math.floor(minutesDecimal);
  const seconds = (minutesDecimal - minutes) * 60;

  const direction = type === CoordinateType.LATITUDE
    ? (value >= 0 ? 'N' : 'S')
    : (value >= 0 ? 'E' : 'W');

  return `${degrees}°${minutes}'${seconds.toFixed(2)}"${direction}`;
}
