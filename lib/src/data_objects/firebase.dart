import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '_data_utils.dart';

final app = Firebase.app();

const _nShards = 2;

String pushKey() => Down4Server.instance.shards[Region.america]![0].realtimeDB
    .ref()
    .push()
    .key!;

int calculateShard(String unique) =>
    unique.codeUnits.fold(0, (p, e) => p + e) % _nShards;

class Down4ServerShard {
  FirebaseDatabase realtimeDB;
  FirebaseStorage staticStore;
  FirebaseStorage temporaryStore;
  Down4ServerShard({
    required this.realtimeDB,
    required this.staticStore,
    required this.temporaryStore,
  });
}

final regex = RegExp(r'^[a-zA-Z_]+\d*$');
Future<bool> isUsernameValid(String username) async {
  if (username.length < 3) {
    print("username=$username is too small");
    return false;
  }
  if (username.length > 32) {
    print("username=$username is too big");
    return false;
  }
  final bool regMatch = regex.hasMatch(username);
  if (!regMatch) {
    print("username=$username does not fit regex rules");
    return false;
  }

  final bool exists = await Down4Server.instance.masterFS
      .collection("users")
      .doc(username)
      .get()
      .then((value) => value.exists);

  if (exists) {
    print("username=$username already exists");
    return false;
  }

  return true;
}

class Down4Server {
  static Down4Server? _instance;
  static Down4Server get instance => _instance ??= Down4Server();

  final masterFS = FirebaseFirestore.instance;

  // final masterDB = FirebaseDatabase.instanceFor(
  //   app: app,
  //   databaseURL: "https://down4-26ee1-default-rtdb.firebaseio.com/",
  // )..setPersistenceEnabled(false);

  // > Server instance are accessed first by region then by index of the shard
  //   that is calculated(once) and saved on any objects that goes onto servers
  //   by calculating once and saving, we can push updates so that new users
  //   will have an index on newer shards possibly, allowing dynamic scaling
  // > User region is calculated on initialization, all objects created by this
  //   user will be in the same regions. Users are the root of all things
  // > There is a masterDB that holds all (usernames:region)
  final Map<Region, List<Down4ServerShard>> shards = {
    Region.america: [
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL: "https://down4-26ee1-fd90e-us1.firebaseio.com/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us1",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us1-tmp",
        ),
      ),
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL: "https://down4-26ee1-c65d2-us2.firebaseio.com/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us2",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us2-tmp",
        ),
      ),
    ],
    Region.europe: [
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-30b1c-eu1.europe-west1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu1",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu1-tmp",
        ),
      ),
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-e487b-eu2.europe-west1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu2",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu2-tmp",
        ),
      ),
    ],
    Region.asia: [
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-8511f-sea1.asia-southeast1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea1",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea1-tmp",
        ),
      ),
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-d98a8-sea2.asia-southeast1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea2",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea2-tmp",
        ),
      ),
    ],
  };
}
