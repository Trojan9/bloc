import 'dart:async';

import 'package:bloc/model/tile.dart';
import 'package:flutter/material.dart';
import 'package:bloc/utils/utility.dart';

void main() {
  runApp(MaterialApp(
    title: '2048',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    home: const TwentyFortyEight(),
  ));
}

enum swipeDirection { up, down, left, right }

class GameState {
  GameState(List<List<Tile>> previousGrid, this.swipe)
      : _previousGrid = previousGrid;

  final swipeDirection swipe;

  // this is the grid before the swipe has taken place
  final List<List<Tile>> _previousGrid;

  // always make a copy so mutations don't screw things up.
  List<List<Tile>> get previousGrid => _previousGrid
      .map((row) => row.map((tile) => tile.copy()).toList())
      .toList();
}

class TwentyFortyEight extends StatefulWidget {
  const TwentyFortyEight({Key key}) : super(key: key);

  @override
  TwentyFortyEightState createState() => TwentyFortyEightState();
}

class TwentyFortyEightState extends State<TwentyFortyEight>
    with SingleTickerProviderStateMixin {
  Timer aiTimer;
  AnimationController controller;
  List<GameState> gameStates = [];
  List<List<Tile>> grid =
      List.generate(4, (y) => List.generate(4, (x) => Tile(x, y, 0)));
  List<Tile> toAdd = [];

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          toAdd.forEach((e) => grid[e.y][e.x].value = e.value);
          gridTiles.forEach((t) => t.resetAnimations());
          toAdd.clear();
        });
      }
    });

    setupNewGame();
  }

  Iterable<Tile> get gridTiles => grid.expand((e) => e);

  Iterable<Tile> get allTiles => [gridTiles, toAdd].expand((e) => e);

  List<List<Tile>> get gridCols =>
      List.generate(4, (x) => List.generate(4, (y) => grid[y][x]));

  void undoMove() {
    GameState previousState = gameStates.removeLast();
    bool Function() mergeFn;
    switch (previousState.swipe) {
      case swipeDirection.up:
        mergeFn = mergeUp;
        break;
      case swipeDirection.down:
        mergeFn = mergeDown;
        break;
      case swipeDirection.left:
        mergeFn = mergeLeft;
        break;
      case swipeDirection.right:
        mergeFn = mergeRight;
        break;
    }
    setState(() {
      grid = previousState.previousGrid;
      mergeFn();
      controller.reverse(from: .99).then((_) {
        setState(() {
          grid = previousState.previousGrid;
          gridTiles.forEach((t) => t.resetAnimations());
        });
      });
    });
  }

  void merge(swipeDirection direction) {
    bool Function() mergeFn;
    switch (direction) {
      case swipeDirection.up:
        mergeFn = mergeUp;
        break;
      case swipeDirection.down:
        mergeFn = mergeDown;
        break;
      case swipeDirection.left:
        mergeFn = mergeLeft;
        break;
      case swipeDirection.right:
        mergeFn = mergeRight;
        break;
    }
    List<List<Tile>> gridBeforeSwipe =
        grid.map((row) => row.map((tile) => tile.copy()).toList()).toList();
    setState(() {
      if (mergeFn()) {
        gameStates.add(GameState(gridBeforeSwipe, direction));
        addNewTiles([2]);
        controller.forward(from: 0);
      }
    });
  }

  bool mergeLeft() => grid.map((e) => mergeTiles(e)).toList().any((e) => e);

  bool mergeRight() =>
      grid.map((e) => mergeTiles(e.reversed.toList())).toList().any((e) => e);

  bool mergeUp() => gridCols.map((e) => mergeTiles(e)).toList().any((e) => e);

  bool mergeDown() => gridCols
      .map((e) => mergeTiles(e.reversed.toList()))
      .toList()
      .any((e) => e);

  bool mergeTiles(List<Tile> tiles) {
    bool didChange = false;
    for (int i = 0; i < tiles.length; i++) {
      for (int j = i; j < tiles.length; j++) {
        if (tiles[j].value != 0) {
          Tile mergeTile = tiles
              .skip(j + 1)
              .firstWhere((t) => t.value != 0, orElse: () => null);
          if (mergeTile != null && mergeTile.value != tiles[j].value) {
            mergeTile = null;
          }
          if (i != j || mergeTile != null) {
            didChange = true;
            int resultValue = tiles[j].value;
            tiles[j].moveTo(controller, tiles[i].x, tiles[i].y);
            if (mergeTile != null) {
              resultValue += mergeTile.value;
              mergeTile.moveTo(controller, tiles[i].x, tiles[i].y);
              mergeTile.bounce(controller);
              mergeTile.changeNumber(controller, resultValue);
              mergeTile.value = 0;
              tiles[j].changeNumber(controller, 0);
            }
            tiles[j].value = 0;
            tiles[i].value = resultValue;
          }
          break;
        }
      }
    }
    return didChange;
  }

  void addNewTiles(List<int> values) {
    List<Tile> empty = gridTiles.where((t) => t.value == 0).toList();
    empty.shuffle();
    for (int i = 0; i < values.length; i++) {
      toAdd.add(Tile(empty[i].x, empty[i].y, values[i])..appear(controller));
    }
  }

  void setupNewGame() {
    setState(() {
      gameStates.clear();
      gridTiles.forEach((t) {
        t.value = 0;
        t.resetAnimations();
      });
      toAdd.clear();
      addNewTiles([2, 2]);
      controller.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    double contentPadding = 16;
    double borderSize = 4;
    double gridSize = MediaQuery.of(context).size.width - contentPadding * 2;
    double tileSize = (gridSize - borderSize * 2) / 4;
    List<Widget> stackItems = [];
    stackItems.addAll(gridTiles.map((t) => TileWidget(
        x: tileSize * t.x,
        y: tileSize * t.y,
        containerSize: tileSize,
        size: tileSize - borderSize * 2,
        color: lightBrown)));
    stackItems.addAll(allTiles.map((tile) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => tile.animatedValue.value == 0
            ? const SizedBox()
            : TileWidget(
                x: tileSize * tile.animatedX.value,
                y: tileSize * tile.animatedY.value,
                containerSize: tileSize,
                size: (tileSize - borderSize * 2) * tile.size.value,
                color: numTileColor[tile.animatedValue.value],
                child: Center(child: TileNumber(tile.animatedValue.value))))));

    return Scaffold(
        backgroundColor: tan,
        body: Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Swiper(
                      up: () => merge(swipeDirection.up),
                      down: () => merge(swipeDirection.down),
                      left: () => merge(swipeDirection.left),
                      right: () => merge(swipeDirection.right),
                      child: Container(
                          height: gridSize,
                          width: gridSize,
                          padding: EdgeInsets.all(borderSize),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(cornerRadius),
                              color: darkBrown),
                          child: Stack(
                            children: stackItems,
                          ))),
                  BigButton(
                      label: "Undo",
                      color: numColor,
                      onPressed: gameStates.isEmpty ? null : undoMove),
                  BigButton(
                      label: "Restart", color: orange, onPressed: setupNewGame),
                ])));
  }
}
