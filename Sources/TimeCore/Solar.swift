import Foundation

/// Solar position using the NOAA/Meeus equations, calculated offline at the preview instant.
/// Apparent sunrise/sunset uses a -0.833° solar-centre altitude (disc + standard refraction).
/// Coordinates are city centres; terrain, elevation and unusual refraction are not modelled.
public enum Solar {
    private static func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func deg(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func normalized(_ value: Double, modulo: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: modulo); return r < 0 ? r + modulo : r
    }
    public static func elevation(at date: Date, location: Coordinates) -> Double {
        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
        let t = (jd - 2451545.0) / 36525.0
        let longitude = normalized(280.46646 + t * (36000.76983 + t * 0.0003032), modulo: 360)
        let anomaly = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let m = rad(anomaly), l = rad(longitude)
        let centre = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) + sin(2 * m) * (0.019993 - 0.000101 * t) + sin(3 * m) * 0.000289
        let omega = rad(125.04 - 1934.136 * t)
        let apparentLongitude = rad(longitude + centre - 0.00569 - 0.00478 * sin(omega))
        let seconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))
        let obliquity = rad(23 + (26 + seconds / 60) / 60 + 0.00256 * cos(omega))
        let declination = asin(sin(obliquity) * sin(apparentLongitude))
        let y = pow(tan(obliquity / 2), 2)
        let equation = 4 * deg(y * sin(2 * l) - 2 * eccentricity * sin(m) + 4 * eccentricity * y * sin(m) * cos(2 * l) - 0.5 * y * y * sin(4 * l) - 1.25 * eccentricity * eccentricity * sin(2 * m))
        let utcMinutes = normalized(date.timeIntervalSince1970, modulo: 86400) / 60
        let solarMinutes = normalized(utcMinutes + equation + 4 * location.longitude, modulo: 1440)
        let hourAngle = rad(solarMinutes / 4 - 180)
        let latitude = rad(location.latitude)
        let cosine = sin(latitude) * sin(declination) + cos(latitude) * cos(declination) * cos(hourAngle)
        return deg(asin(min(1, max(-1, cosine))))
    }
    public static func isDaylight(at date: Date, location: Coordinates) -> Bool {
        elevation(at: date, location: location) >= -0.833
    }
}
