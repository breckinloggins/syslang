public class Machine  {
  public Stack ds;
  public Stack rs;
  public ArrayList<Word> dictionary;
  public Word currentWord;
  public Terminal term;
  public Interpreter interp; 
  
  Machine()  {
    ds = new Stack("DS");
    rs = new Stack("RS");
    dictionary = new ArrayList<Word>();
    currentWord = null;
    interp = new Interpreter(this);
    term = new Terminal(interp);
  }
  
  public void update()  {
    ds.update();
    rs.update();
    interp.update();
    term.update(); 
  }
}
