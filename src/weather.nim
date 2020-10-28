# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.
import os
import system
import tables
import times
import json
import strutils
import strformat
import httpclient
import parseopt
import parsecfg

let APIKEY = os.getEnv("OPEN_WEATHERMAP_APIKEY")

if APIKEY == "":
  echo "Please set APIKEY to $OPEN_WEATHERMAP_APIKEY"
  quit(-1)

type CityData = object
  name: string
  lat: float
  lon: float

type Mode = enum
  Current,
  Daily

type WeatherKind = enum
  Clouds = "☁️",
  Snow = "⛄️",
  Rain = "☂️",
  Clear = "☀️",
  Thunder = "⚡️",
  Mist = "🌫",
  Unknown = "❔"

type WeatherInfo = object
  date: DateTime
  weather: WeatherKind
  temp: float
  humidity: int
  windSpeed: float

proc buildURL(baseUrl: string, queries: Table): string =
  result = baseUrl & "?"
  var l: seq[string]
  for k, v in queries.pairs:
    l.add(k & "=" & v)
  return result & l.join("&")

proc showWeatherInfo(wi: WeatherInfo) =
  echo    "┌" & "─".repeat(24) & "┐"
  echo fmt"│ {wi.date.month:9} {wi.date.monthDay:2} {wi.date.weekDay:9} │"
  echo    "├" & "─".repeat(24) & "┤"
  echo    "│         " & fmt"temp: {wi.temp:.1f}°C   │"
  echo fmt"│   {wi.weather}     humidity: {wi.humidity:2}%  │"
  echo    "│         " & fmt"wind: {wi.windSpeed:4.1f}m/s  │"
  echo    "└" & "─".repeat(24) & "┘"

proc kelvin2Celsius(k: float): float =
  return k - 273.15

proc str2WeatherKind(weatherStr: string): WeatherKind =
  result = case weatherStr:
    of "Clear":
      WeatherKind.Clear
    of "Clouds":
      WeatherKind.Clouds
    of "Rain":
      WeatherKind.Rain
    of "Mist":
      WeatherKind.Mist
    else:
      WeatherKind.Unknown
  return

proc parseCurrentWeatherData(wd: JsonNode): seq[WeatherInfo] =
  let weather = wd["weather"][0]["main"].getStr()
  let temp = wd["main"]["temp"].getFloat().kelvin2Celsius()
  let humidity = wd["main"]["humidity"].getInt()
  let windSpeed = wd["wind"]["speed"].getFloat()
  let weatherInfo = WeatherInfo(
    date: now(),
    weather: weather.str2WeatherKind(),
    temp: temp,
    humidity: humidity,
    windSpeed: windSpeed,
  )
  result.add(weatherInfo)
  return

proc parseDailyWeatherData(wd: JsonNode): seq[WeatherInfo] =
  let dailyData = wd["daily"]
  for weatherData in dailyData:
    let dt = weatherData["dt"].getInt().fromUnix().local()
    let weather = weatherData["weather"][0]["main"].getStr()
    let temp = weatherData["temp"]["day"].getFloat().kelvin2Celsius()
    let humidity = weatherData["humidity"].getInt()
    let windSpeed = weatherData["wind_speed"].getFloat()
    let weatherInfo = WeatherInfo(
      date: dt,
      weather: weather.str2WeatherKind(),
      temp: temp,
      humidity: humidity,
      windSpeed: wind_speed,
    )
    result.add(weatherInfo)
  return

proc currentWeatherURL(city: CityData): string = 
  let baseUrl = "https://api.openweathermap.org/data/2.5/weather"
  let query = {"q": city.name, "appid": APIKEY}.toTable
  return baseUrl.buildURL(query)

proc dailyWeatherURL(city: CityData): string = 
  let baseUrl = "https://api.openweathermap.org/data/2.5/onecall"
  let query = {"lat": $city.lat, "lon": $city.lon, "appid": APIKEY}.toTable
  return baseUrl.buildURL(query)

when isMainModule:
  var p = initOptParser(commandLineParams().join(" "))
  var mode = Mode.Current;
  # parse options
  while true:
    p.next()
    case p.kind:
      of cmdEnd:
        break
      of cmdShortOption:
        if p.key == "d":
          mode = Mode.Daily
      of cmdLongOption:
        if p.key == "daily":
          mode = Mode.Daily
      of cmdArgument:
        continue
  # parse config
  var confDict = loadConfig("./config.ini")
  let cityName = confDict.getSectionValue("City", "name")
  let cityLatitude = confDict.getSectionValue("City", "lat").parseFloat
  let cityLongitude = confDict.getSectionValue("City", "lon").parseFloat

  let city = CityData(
    name: cityName,
    lat: cityLatitude,
    lon: cityLongitude,
  )

  # generate URL
  let url = case mode:
    of Mode.Current:
      currentWeatherURL(city);
    else:
      dailyWeatherURL(city)

  # fetch
  let client = newHttpClient()
  let jsonData = client.getContent(url).parseJSON()

  # parse API response
  let weatherList = case mode:
    of Mode.Current:
      jsonData.parseCurrentWeatherData
    else:
      jsonData.parseDailyWeatherData

  # show weather info
  for wd in weatherList:
    wd.showWeatherInfo()
