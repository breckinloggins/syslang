public void InitializeBuiltins(HashMap<String, Word> dictionary)  {
  for (String name : new String[]{".", "+", "*"})  {
    dictionary.put(name, new Word(name)); 
  }
}
  
public class Word {
  public String name;
  
  Word(String name)  {
    this.name = name;
  }
  
  public void execute(Terminal term, Stack ds, Stack rs)  {
    try  {
      if (name.equals("."))  {
        term.println("" + ds.pop());
      } else if (name.equals("+")) {
        int a1 = ds.pop();
        int a2 = ds.pop();
        ds.push(a1 + a2);
      } else if (name.equals("*")) {
        int a1 = ds.pop();
        int a2 = ds.pop();
        ds.push(a1 * a2);
      } else {
        term.println("error: " + name + " does not have defined execution semantics");
      }
    } catch (SyslangException ex)  {
      term.println("error executing " + name + ": " + ex.getMessage()); 
    } 
  }
}
