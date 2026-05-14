#pragma once

struct DhtReading
{
    float temperatureC;
    float humidityPercent;
};

DhtReading readDht11();
