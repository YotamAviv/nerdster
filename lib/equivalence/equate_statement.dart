
/// 
class EquateStatement {
  String canonical; // NOTE: canonical is meaningless when !same.
  String equivalent;
  final bool dont;
  
  EquateStatement(this.canonical, this.equivalent, {this.dont = false});
}

