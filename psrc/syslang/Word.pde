public void InitializeBuiltins(ArrayList<Word> dictionary)  {
  for (String name : new String[]{"create", ".", "+", "*"})  {
    dictionary.add(new Word(name)); 
  }
}
  
public class Word {
  public String name;
  
  Word(String name)  {
    this.name = name;
  }
  
  public void execute(Machine m)  {
    try  {
      if (name.equals("create"))  {
        
      } else if (name.equals("."))  {
        m.term.println("" + m.ds.pop());
      } else if (name.equals("+")) {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a1 + a2);
      } else if (name.equals("*")) {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a1 * a2);
      } else {
        m.term.println("error: " + name + " does not have defined execution semantics");
      }
    } catch (SyslangException ex)  {
      m.term.println("error executing " + name + ": " + ex.getMessage()); 
    } 
  }
}
