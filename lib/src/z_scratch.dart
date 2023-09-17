void main() async {
  print("jeff");
  await Future.delayed(const Duration(seconds: 1));
  print("andrew after 1 second");

  final sbuf = StringBuffer("""
    BEGIN TRANSACTION;

""");

  sbuf.write("""
    SELECT * FROM caca;
""");

  sbuf.write("""
    DELETE FROM niggas WHERE age > '10';
""");

  print(sbuf.toString());
}
