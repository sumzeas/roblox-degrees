# roblox-degrees

"*Six degrees of separation is the idea that all people are six or fewer social connections away from each other.*" - [Wikipedia](https://en.wikipedia.org/wiki/Six_degrees_of_separation)

How many connections away are you from your favorite Roblox player?

This tool finds the shortest friendship path between two Roblox users using the Roblox friends network.

## Requirements
* LuaRocks (3.13.0)
* SQLite (3.45.1)

## Getting Started

**1.** Verify dependencies:
```bash
luarocks --version
sqlite3 --version
```

**2.** Install project dependencies:
```bash
luarocks make
```

**3.** Run the program:
```bash
lua main.lua (username1) (username2)
```

> **Note:** Roblox API rate limits make initial searches slow. Results are cached in SQLite, so repeated queries get faster over time.


## Example
```bash
lua main.lua user1 user2
Elapsed: _____.__s | Searched: _________ | Queued: ________ | Depth:   _
Degrees of separation:  3
user1
|
friend1
|
friend2
|
user2
```
> **Note:** These are not real users.

## How it works
* Performs a **bidirection breadth-first-search** (BFS) on the Roblox friends graph.
* Stores visited users locally in SQLite to avoid repeated API calls.

## Troubleshooting

### Slow performance
This is to be expected when running for the first time or inputting new users. Come back later and check if the path was found.

### No path found
You found a lonely user.

### Error 403
One user has their profile private.
