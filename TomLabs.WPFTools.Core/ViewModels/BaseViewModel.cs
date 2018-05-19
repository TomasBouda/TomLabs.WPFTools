using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Reflection;

namespace TomLabs.WPFTools.Core.ViewModels.Base
{
	public class BaseViewModel : INotifyPropertyChanged
	{
		/// <summary>
		/// The event that is fired when any child property changes its value
		/// </summary>
		public event PropertyChangedEventHandler PropertyChanged;

		public bool HasErrors => _validationErrors.Count > 0;

		private readonly Dictionary<string, ICollection<string>> _validationErrors = new Dictionary<string, ICollection<string>>();

		public event EventHandler<DataErrorsChangedEventArgs> ErrorsChanged;

		public IEnumerable GetErrors(string propertyName)
		{
			if (string.IsNullOrEmpty(propertyName)
			|| !_validationErrors.ContainsKey(propertyName))
				return null;

			return _validationErrors[propertyName];
		}

		protected void RaiseErrorsChanged(string propertyName)
		{
			ErrorsChanged?.Invoke(this, new DataErrorsChangedEventArgs(propertyName));
		}

		protected void ValidateModelProperty<T>(object value, string propertyName)
		{
			if (_validationErrors.ContainsKey(propertyName))
				_validationErrors.Remove(propertyName);

			PropertyInfo propertyInfo = typeof(T).GetProperty(propertyName);
			IList<string> validationErrors =
				  (from validationAttribute in propertyInfo.GetCustomAttributes(true).OfType<ValidationAttribute>()
				   where !validationAttribute.IsValid(value)
				   select validationAttribute.FormatErrorMessage(string.Empty))
				   .ToList();

			if (validationErrors.Count > 0)
			{
				_validationErrors.Add(propertyName, validationErrors);
			}

			RaiseErrorsChanged(propertyName);
		}

		protected virtual bool ValidateModel(object context)
		{
			_validationErrors.Clear();
			ICollection<ValidationResult> validationResults = new List<ValidationResult>();
			ValidationContext validationContext = new ValidationContext(context, null, null);
			if (!Validator.TryValidateObject(context, validationContext, validationResults, true))
			{
				foreach (ValidationResult validationResult in validationResults)
				{
					string property = validationResult.MemberNames.ElementAt(0);
					if (_validationErrors.ContainsKey(property))
					{
						_validationErrors[property].Add(validationResult.ErrorMessage);
					}
					else
					{
						_validationErrors.Add(property, new List<string> { validationResult.ErrorMessage });
					}
				}
			}

			/* Raise the ErrorsChanged for all properties explicitly */


			return HasErrors;
		}
	}
}
