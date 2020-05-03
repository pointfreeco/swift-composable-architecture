# Search

This application demonstrates how to build a moderately complex search feature in the Composable Architecture:

* Typing into the search field executes an API request to search for locations.
* Tapping a location runs another API request to fetch the weather for that location, and when a response is received the data is displayed inline in that row.

In addition to those basic features, the following extra things are implemented:

* Search API requests are debounced so that one is run only after the user stops typing for 300ms.
* If you tap a location while a weather API request is already in-flight it will cancel that request and start a new one.
* Dependencies and side effects are fully controlled. The reducer that runs this application needs a [weather API client](Search/WeatherClient.swift) and a scheduler to run effects.
* A full [test suite](SearchTests/SearchTests.swift) is implemented. Not only is core functionality tested, but also failure flows and subtle edge cases (e.g. clearing the search query cancels any in-flight search requests).
