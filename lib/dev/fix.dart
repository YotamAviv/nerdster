import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// How embarrassing! 
/// I had a bug back somewhere around 2024-09-15T20:40:08.537255Z that lead to 2 statements in my data with that exact same date.
/// For better or worse, the order served by Firebase sorted by time always provided the 2 statements in a favorable order, and so I didn't notice until recently.
/// My options included: 
/// 1) ignoring the data corruption and hope that Firebase sort remains favorable, 
/// 2) replacing my key, 
/// 3) backdate all of my statements. (selected)
/// 
/// This file is checked in cuz why not.
/// 
/// Here are my notes and stuff from that day:
/// 
/// Plan
/// Emulator:
/// - save to this file
///   - http://127.0.0.1:5002/one-of-us-net/us-central1/export3?token=2c3142d16cac3c5aeb6d7d40a4ca6beb7bd92431
///     - this required local changes to keep "I", and "statement"
///   - my ONE-OF-US private key 
/// 
/// - run UI (local machine, local code changes, emulator)
/// - manually delete my collection (Firebase console on emulator)
/// - call FIX from DEV menu
/// - fix writes my new collection
/// - look around and verify
/// 
/// PROD:
/// - backup
/// - use PROD
/// - same as above

List<Json> input = [
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "M7l7bQBumX2Z-Rhh8M2nvgupd65ZwNn8x0uHY7H5bRY"
    },
    "with": {
      "moniker": "Eyal F"
    },
    "previous": "bf020f1641972aed5cbd4c6c040f78e5d936e105",
    "signature": "268613a844523fe8682ced911f724df04d9502056dd172ffa6b5b9dec5ee9d29ffc5748d71da3c8625511a928f97ae0639b8c4e1321135d964b36c588f718907",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2025-02-17T14:22:24.842019Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "bYhOIKTEqwDe1tmlrtDAtSw9EPeXl_tto5euQpt_v50"
    },
    "with": {
      "moniker": "Dave A"
    },
    "previous": "0b722db7792bded22aac2e15f96252b93697f44d",
    "signature": "c76b5b44c0ef7a6705f06027cedfaf0ef29dc7d6a5ecca715c78f3587dfda9a188f1f318bd66c94798d5b3a93b585dd4f2b54aa3b5004b153174cf8c235a5005",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2025-02-17T13:26:50.994021Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "zzWDiUybV6Yj7Fp-frynBZbwHGaL8EDe18NB1DJebp4"
    },
    "with": {
      "moniker": "Mateo"
    },
    "previous": "23312edb46f928221108d381e9f495a27dd14bea",
    "signature": "b814b00e2dd9821517c9cff9473d919f9c5700889f30d7fc1bdb86037dba6632ad4ac825340783fca3f0504b417562d9cd7ce0c7ed05145de0e960cfcba27501",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-12-16T14:16:45.852751Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "2gHnIE6_rm53Q3ktKlih7kjWncPJV3Qc-dtfm3vJsT8"
    },
    "with": {
      "moniker": "A J"
    },
    "previous": "2ff10a011565945334dade51c83aa05341273d7b",
    "signature": "85ae367e0a334c3f44b710cd2af2d93583c18de334176412a6f21a086cb4d9ecf894a43c0785c1a560483fdb96f567e14f48906be7e7292115cb3d7589dc1705",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-12-06T03:23:59.746485Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "-FHOdDNxrUFw2EGCeZiTPIWjK8tn2AsgJL59FqABw2s"
    },
    "with": {
      "moniker": "Jason"
    },
    "previous": "7dc02478bd9b833aa2796b92eaa27a4f7ac04268",
    "signature": "4b76018eb47217a4cd31dc15e3046623c2f1b84d16e1c99e687fd75fac8d64365c02a06c0a596e1f4d109ef37531ed4401c9bfb45e004f27a0bb4229855d8000",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-12-02T20:07:10.834537Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "G1_KSd2E-V62L8tQIFNmdk2sObHxYAAmk8gVtHQDf84"
    },
    "with": {
      "moniker": "James"
    },
    "previous": "5567c965d7d5991e7045227caed8e7e54df85ecf",
    "signature": "9b507226a002e8ad541b23b6627589453586f7626dbf7c0f9b508f3416e28bfa7ccac2fca6a1386cf5f1c82cb96a175887c9106498ca5cb39d0ceaf180c6140c",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-11-27T22:33:58.542104Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "-bxsrml3jcHQdscHhruRyrP97SGT1J-jJMKD7cRCPKw"
    },
    "with": {
      "moniker": "Hillel M"
    },
    "previous": "81f9855ab455df464c413ab462c2edf897315848",
    "signature": "9f7706062ea3c01eb3819e9e2370e4a3f8e11af069da2cc70f19c2673c1a1ee0a876fd20bbf4a84c050cc7ffb9ebd7ec9cff7e92794b236b81251640677ab507",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "comment": "former colleague\na true and loyal friend",
    "time": "2024-11-27T18:11:04.748412Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "o4fdtWGHNblOhMHDYgoYX4Vi86k9AGUTpcZHfZHZEOQ"
    },
    "with": {
      "moniker": "Andrew"
    },
    "previous": "5fc49aef05ba0ef6f9a547de0f1857aaf596371a",
    "signature": "9c896b3be4bb055c990af31fee594cc9e4343a73651bb546c4fa2b68a7da2f6a1d50f510e5ac43cf4b09955fbaed2aae8b4f3ab2d56552af915eb75ae284ee04",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-11-17T23:18:36.226803Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "0b2c56f59114dd47f5f394810ee60b7a5da1fe61",
    "signature": "b8f7b5b39f47920b2842d80114e8cdf23c33d61b2b995490cfc665244212acbcd3ddc5f77cff47eca0a1b42b33a6564ebe4d8bb00d0d01922f6b9fe61589480d",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "comment": "cousin",
    "time": "2024-10-22T15:43:40.475401Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "LxcgcUEK-djXUcMRg2qJSd00hqw89EP0Pc9iocw2UcE"
    },
    "with": {
      "moniker": "Dave"
    },
    "previous": "ab00bf4de0b0cd54b34e0ab7270ea007e2064c02",
    "signature": "be1b5c9c56b38d71e9f319fca67b755d97a398f44090a2126cf0808603cc5f1a9f1e83a6172e36b25683ab4cfc759872950dbf796a8b0cb3ade3c163b4d1ff0e",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-10-21T14:36:56.162455Z"
  },
  {
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "3d04f603614e07cf7cc6dad7405cdb322f0a3570",
    "signature": "6e7ec51039fa9cbf741d3ca08d766486547f8e1604961717cdf94c9d99e698a14368c6c52f3a55c7b1eae84b9af8e00d97637a1f8c1fa4471ee91225eb554109",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-10-18T17:24:13.692677Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "_Gy7YmUG6FR0e2J2Drojz72Kv6yyHVVlJOHHoH6apdQ"
    },
    "with": {
      "moniker": "Hillel TT"
    },
    "previous": "a6ff811ff25f0a3b69e45627f8a3e30df940abce",
    "signature": "5bcef98df422ca1117244a618b4c5bac998bc04ae7b45d6d0af2299f43786ee37e018fd1130c5f59b365ac40fa205744e569cb277ef77e326fba4a3f1047d306",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "comment": "cousin",
    "time": "2024-09-13T17:27:02.004843Z"
  }
];

Json yotamKeyPair = {
  // hidden
};

class Fix {
  static Future<void> fix() async {
    
    OouKeyPair keyPair = await crypto.parseKeyPair(yotamKeyPair);
    OouPublicKey publicKey = await keyPair.publicKey;
    String yotamToken = getToken(await publicKey.json);
    Fetcher fetcher = Fetcher(yotamToken, kOneofusDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    String? previous;
    for (Json json in input.reversed) {
      json = Map.from(json);
      json.remove('signature');
      json.remove('previous');
      if (previous != null) json['previous'] = previous;

      Jsonish jsonish = await fetcher.push(json, signer);
      previous = jsonish.token;

      print('.');
    }
    print('FIX done.');
  }
}