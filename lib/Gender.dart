enum Gender { male, female }

extension on Gender {}

Gender stringToGender(String genderSt) {
  if (genderSt == "male") {
    return Gender.male;
  }
  return Gender.female;
}
