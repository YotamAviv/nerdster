I ran the egosCircle demo on production and
manually corrupted one of the statements in Poser's delegate key collection.
See: corrupt_egos_poser_delegate.json
I correctly see the notification at (using hipster's identity) at:
?fire=prod&identity={%22crv%22:%20%22Ed25519%22,%22kty%22:%20%22OKP%22,%22x%22:%20%22Sf-EQHCY94WB_4QFzEQWkO2SYFNTBgtfsc-Ic25oL84%22}&skipVerify=false&dev=true
?fire=emulator&identity={%22crv%22:%20%22Ed25519%22,%22kty%22:%20%22OKP%22,%22x%22:%20%22Sf-EQHCY94WB_4QFzEQWkO2SYFNTBgtfsc-Ic25oL84%22}&skipVerify=false&dev=true


I ran the egosCircle demo on production and
manually deleted one of the statements in Poser's delegate key collection.
See: corrupt_egos_poser_delegate_missing_statement.json
I expect to see the notification (using hipster's identity):
?fire=emulator&identity={"crv": "Ed25519","kty": "OKP","x": "bNGvuBKSoDCHlYWzBMRVzfBgQK-Rr34jkVI_EdMOjcw"}&skipVerify=false&dev=true
?fire=prod&identity={"crv": "Ed25519","kty": "OKP","x": "bNGvuBKSoDCHlYWzBMRVzfBgQK-Rr34jkVI_EdMOjcw"}&skipVerify=false&dev=true

TODO: Test corrupted identity keys on the ONE-OF-US.NET servers

********** scratch **************

http://127.0.0.1:5001/nerdster/us-central1/export?spec=%2275138a1f1316da7740d2c64b40f3dabb5101206a%22&includeId=true&checkPrevious=true
returns:
{"75138a1f1316da7740d2c64b40f3dabb5101206a":{"error":"Notarization violation: f7946555c69f8a6a53d6588c27423f1310f3c0da != ebae0cc624a356eb77870b90e1ba9874dcf060a3"}}

http://127.0.0.1:5001/nerdster/us-central1/export?spec=[75138a1f1316da7740d2c64b40f3dabb5101206a,0b4f26a2ccc8eccb21d3a04a3aaf71635ce93c39]&includeId=true&checkPrevious=true

http://127.0.0.1:5001/nerdster/us-central1/export?spec=["75138a1f1316da7740d2c64b40f3dabb5101206a","0b4f26a2ccc8eccb21d3a04a3aaf71635ce93c39"]&includeId=true&checkPrevious=true
returns:
{"75138a1f1316da7740d2c64b40f3dabb5101206a":{"error":"Notarization violation: f7946555c69f8a6a53d6588c27423f1310f3c0da != ebae0cc624a356eb77870b90e1ba9874dcf060a3"}}
{"0b4f26a2ccc8eccb21d3a04a3aaf71635ce93c39":[{"statement":"org.nerdster","time":"2026-01-05T21:36:05.150Z","I":{"crv":"Ed25519","kty":"OKP","x":"hMQcscBNi-BM95CohgY3n8wczcir7836a9_DvpQk7pk"},"rate":"ebae0cc624a356eb77870b90e1ba9874dcf060a3","with":{"recommend":true},"comment":"Thanks!","previous":"078c702b07e274bbf2ac8055a89b5fd91098748d","id":"03b0f18eaf41c03aabd0a0cd120beebfc856eab1","signature":"c7d7b66a9c8ae8a66004fbaebb167596b8af7454eb10a20378e9facf61efbfc71ce3e698a55fd11a029b8e4da420718e90f6f56107f6e89238a815d25c73fc05"},{"statement":"org.nerdster","time":"2026-01-05T21:36:03.921Z","I":{"crv":"Ed25519","kty":"OKP","x":"hMQcscBNi-BM95CohgY3n8wczcir7836a9_DvpQk7pk"},"rate":{"contentType":"article","title":"25+ Coolest Sleeve Tattoos for Men  | Man of Many","url":"https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"},"with":{"recommend":true},"id":"078c702b07e274bbf2ac8055a89b5fd91098748d","signature":"bb41b19104309a5359dff4f97f17a63819915d8777fa9186ff2adca19836d7dec34443709ccf9cfb0c33a647e3806b74c06ac70adcc640f7c85ec6e452d05700"}]}