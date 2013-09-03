public class Machine  {
  public Stack ds;
  public Stack rs;
  public ArrayList<Word> dictionary;
  public Terminal term;
  public Interpreter interp; 
  
  Machine()  {
    ds = new Stack("DS");
    rs = new Stack("RS");
    dictionary = new ArrayList<Word>();
    interp = new Interpreter(this);
    term = new Terminal(interp);
  }
}
